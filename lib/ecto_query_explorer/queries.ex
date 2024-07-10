defmodule EctoQueryExplorer.Queries do
  import Ecto.Query

  alias EctoQueryExplorer.{Query, Params}

  def base_query do
    from q in Query,
      as: :query,
      join: s in assoc(q, :samples),
      left_join: p in assoc(s, :params),
      as: :params,
      join: st in assoc(s, :stacktrace),
      join: se in assoc(st, :stacktrace_entries),
      join: f in assoc(se, :function),
      as: :function,
      join: l in assoc(se, :location),
      as: :location,
      preload: [
        samples:
          {s,
           [
             params: p,
             stacktrace: {st, [stacktrace_entries: {se, [function: f, location: l]}]}
           ]}
      ],
      order_by: {:asc, se.index}
  end

  def filter_by_query(string) do
    Application.get_env(:ecto_query_explorer, :repo).all(
      from [query: q] in base_query(), where: like(q.text, ^string)
    )
  end

  def filter_by_parameter(value) do
    repo = Application.get_env(:ecto_query_explorer, :repo)

    {:ok, sample_ids} =
      repo.transaction(fn ->
        Params
        |> repo.stream()
        |> Stream.filter(&(value in :erlang.binary_to_term(&1.values)))
        |> Stream.map(& &1.sample_id)
        |> Enum.to_list()
      end)

    repo.all(from [params: p] in base_query(), where: p.sample_id in ^sample_ids)
  end

  def filter_by_mfa(module, function, arity) do
    Application.get_env(:ecto_query_explorer, :repo).all(
      from [function: f] in base_query(),
        where: f.module == ^to_string(module),
        where: f.function == ^to_string(function),
        where: f.arity == ^arity
    )
  end

  def filter_by_location(file, line) do
    Application.get_env(:ecto_query_explorer, :repo).all(
      from [location: l] in base_query(),
        where: l.file == ^file,
        where: l.line == ^line
    )
  end

  def explain(query_id) do
    query =
      Application.get_env(:ecto_query_explorer, :repo).one!(
        from [query: q] in base_query(), where: q.id == ^query_id
      )

    explain_parameters = "analyze, costs, verbose, buffers, format json"

    text = query.text
    sample = List.first(query.samples)
    params = sample.params

    if is_nil(params) do
      {:error, :sample_with_params_not_found}
    else
      {:error, explain} =
        String.to_atom(query.repo).transaction(fn repo ->
          %Postgrex.Result{
            rows: [
              [[explain]]
            ]
          } =
            repo.query!(
              "explain (#{explain_parameters}) #{text}",
              :erlang.binary_to_term(params.values)
            )

          repo.rollback(explain)
        end)

      explain
    end
  end

  def top_queries(limit \\ 10) do
    Application.get_env(:ecto_query_explorer, :repo).all(
      from q in Query,
        select: %{
          id: q.id,
          count: q.counter,
          text: q.text
        },
        order_by: {:desc, q.counter},
        limit: ^limit
    )
  end
end

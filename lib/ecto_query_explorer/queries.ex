defmodule EctoQueryExplorer.Queries do
  import Ecto.Query

  alias EctoQueryExplorer.{Query, Sample}

  def base_query do
    from q in Query,
      as: :query,
      join: s in assoc(q, :samples),
      as: :samples,
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
        Sample
        |> repo.stream()
        |> Stream.filter(&(value in :erlang.binary_to_term(&1.params)))
        |> Stream.map(& &1.id)
        |> Enum.to_list()
      end)

    repo.all(from [samples: s] in base_query(), where: s.id in ^sample_ids)
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

  def explain(sample_id) do
    %{
      repo: repo,
      text: text,
      values: values
    } =
      Application.get_env(:ecto_query_explorer, :repo).one!(
        from s in Sample,
          where: s.id == ^sample_id,
          join: q in assoc(s, :query),
          select: %{
            repo: q.repo,
            text: q.text,
            values: s.params
          }
      )

    explain_parameters = "analyze, costs, verbose, buffers, format json"

    {:error, result} =
      String.to_atom(repo).transaction(fn repo ->
        %Postgrex.Result{rows: [[[result]]]} =
          repo.query!("explain (#{explain_parameters}) #{text}", :erlang.binary_to_term(values))

        repo.rollback(result)
      end)

    result
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

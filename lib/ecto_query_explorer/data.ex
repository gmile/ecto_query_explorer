defmodule EctoQueryExplorer.Data do
  @moduledoc """
  Functions for managing collected telemetry data.

  Data flows: ETS (runtime) → SQLite (persistent storage)

  ## Usage

      # Check what has been collected since the last flush
      EctoQueryExplorer.Data.ets_stats()

      # Flush every connected node to SQLite now
      EctoQueryExplorer.Data.dump2sqlite()

      # Check SQLite table sizes
      EctoQueryExplorer.Data.repo_stats()

  ## Dumps

  Each node records its data under a dump named after it, so you can see
  which node a sample came from.
  """

  import Ecto.Query, only: [from: 2]

  alias EctoQueryExplorer.{
    Dump,
    Query,
    Sample,
    Stacktrace,
    StacktraceEntry,
    Function,
    Location
  }

  @sqlite_params_limit 32766

  @tables [
    queries: {Query, [:text, :repo, :source, :counter]},
    locations: {Location, [:file, :line]},
    functions: {Function, [:module, :function, :arity]},
    stacktraces: {Stacktrace, [:counter]},
    samples: {Sample, [:query_id, :total_time, :queue_time, :query_time, :decode_time, :stacktrace_id, :params]},
    stacktrace_entries: {StacktraceEntry, [:stacktrace_id, :function_id, :location_id, :index]}
  ]

  def ets_stats do
    ets_table = Application.fetch_env!(:ecto_query_explorer, :ets_table_name)

    %{
      total_records: :ets.info(ets_table, :size),
      total_memory: :ets.info(ets_table, :memory) * :erlang.system_info(:wordsize)
    }
  end

  def repo_stats do
    repo = Application.fetch_env!(:ecto_query_explorer, :repo)

    sqlite_stats = """
    with
    records as (
      select 'dumps' name, count(1) total_records from dumps
      union
      select 'queries' name, count(1) total_records from queries
      union
      select 'samples' name, count(1) total_records from samples
      union
      select 'functions' name, count(1) total_records from functions
      union
      select 'locations' name, count(1) total_records from locations
      union
      select 'stacktraces' name, count(1) total_records from stacktraces
      union
      select 'stacktrace_entries' name, count(1) total_records from stacktrace_entries
    ),
    sizes as (
        select SUM(pgsize) bytes,
               name
          from dbstat
         where name in ('dumps', 'queries', 'samples', 'functions', 'locations', 'stacktrace_entries', 'stacktraces')
      group by name
    )
      select r.name,
             total_records,
             bytes
        from records r
        join sizes s on s.name = r.name
    order by bytes desc
    """

    repo.query!(sqlite_stats)
  end

  @doc """
  Moves the data collected on every connected node into the SQLite database.

  This also happens on its own every `:flush_interval`. Counters are added to
  the ones already stored. Returns `:ok`, or `{:error, failures}` listing the
  nodes whose data could not be written.

  ## Options

    * `:name` - Name of the dump to record this flush under, on every node.
      Defaults to each node's name.

  ## Examples

      EctoQueryExplorer.Data.dump2sqlite()
      EctoQueryExplorer.Data.dump2sqlite(name: "v1.2.3")
  """
  def dump2sqlite(opts \\ []) do
    EctoQueryExplorer.Writer.flush(opts)
  end

  @doc false
  def merge(rows, dump_name) do
    repo = Application.fetch_env!(:ecto_query_explorer, :repo)
    grouped = Enum.group_by(rows, &elem(elem(&1, 0), 0))

    {:ok, :ok} =
      repo.transaction(fn ->
        dump_id = create_dump(repo, dump_name)

        for {kind, {schema, columns}} <- @tables, kind_rows = grouped[kind] do
          [item | _] = items = Enum.map(kind_rows, &item(&1, schema, columns, dump_id))
          conflict = if :counter in columns, do: add_counter(schema), else: [on_conflict: :nothing]

          items
          |> Enum.chunk_every(div(@sqlite_params_limit, map_size(item)))
          |> Enum.each(&repo.insert_all(schema, &1, conflict))
        end

        trim_samples(repo, grouped[:samples], Application.get_env(:ecto_query_explorer, :samples_to_keep))
      end)

    :ok
  end

  defp create_dump(repo, name) do
    {_, [%{id: dump_id}]} =
      repo.insert_all(Dump, [%{name: name, collected_at: DateTime.utc_now()}],
        on_conflict: {:replace, [:collected_at]},
        conflict_target: [:name],
        returning: [:id]
      )

    dump_id
  end

  defp item(row, schema, columns, dump_id) do
    [{_kind, id} | values] = Tuple.to_list(row)

    item = columns |> Enum.zip(values) |> Map.new()
    item = if schema == Sample, do: item, else: Map.put(item, :id, id)

    if :dump_id in schema.__schema__(:fields), do: Map.put(item, :dump_id, dump_id), else: item
  end

  defp add_counter(schema) do
    [
      on_conflict: from(s in schema, update: [set: [counter: fragment("counter + excluded.counter")]]),
      conflict_target: [:id]
    ]
  end

  defp trim_samples(_repo, samples, samples_to_keep) when is_nil(samples) or is_nil(samples_to_keep), do: :ok

  defp trim_samples(repo, samples, samples_to_keep) do
    query_ids = samples |> Enum.map(&elem(&1, 1)) |> Enum.uniq() |> Enum.join(",")

    repo.query!(
      """
      delete from samples
       where id in (
         select id
           from (
             select id,
                    row_number() over (partition by query_id, stacktrace_id order by total_time desc, id desc) position
               from samples
              where query_id in (select value from json_each(?1))
           )
          where position > ?2
       )
      """,
      ["[#{query_ids}]", samples_to_keep]
    )

    :ok
  end
end

defmodule EctoQueryExplorer.Data do
  require Logger

  alias EctoQueryExplorer.{
    Query,
    Sample,
    Stacktrace,
    StacktraceEntry,
    Function,
    Location
  }

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
         where name in ('queries', 'samples', 'functions', 'locations', 'stacktrace_entries', 'stacktraces')
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

  def dump2sqlite do
    ets_table = Application.fetch_env!(:ecto_query_explorer, :ets_table_name)
    repo = Application.fetch_env!(:ecto_query_explorer, :repo)

    queries_spec =
      {{{:queries, :"$1"}, :"$2", :"$3", :"$4", :"$5"}, [],
       [%{id: :"$1", text: :"$2", repo: :"$3", source: :"$4", counter: :"$5"}]}

    samples_spec =
      {{{:samples, :"$1"}, :"$2", :"$3", :"$4", :"$5", :"$6", :"$7", :"$8"}, [],
       [
         %{
           id: :"$1",
           query_id: :"$2",
           total_time: :"$3",
           queue_time: :"$4",
           query_time: :"$5",
           decode_time: :"$6",
           stacktrace_id: :"$7",
           params: :"$8"
         }
       ]}

    functions_spec =
      {{{:functions, :"$1"}, :"$2", :"$3", :"$4"}, [], [%{id: :"$1", module: :"$2", function: :"$3", arity: :"$4"}]}

    locations_spec =
      {{{:locations, :"$1"}, :"$2", :"$3"}, [], [%{id: :"$1", file: :"$2", line: :"$3"}]}

    stacktrace_entries_spec =
      {{{:stacktrace_entries, :"$1"}, :"$2", :"$3", :"$4", :"$5"}, [],
       [
         %{
           id: :"$1",
           stacktrace_id: :"$2",
           function_id: :"$3",
           location_id: :"$4",
           index: :"$5"
         }
       ]}

    stacktraces_spec =
      {{{:stacktraces, :"$1"}, :"$2"}, [],
       [
         %{
           id: :"$1",
           counter: :"$2"
         }
       ]}

    [
      {{:queries, :_}, :_, :_, :_, :_},
      {{:samples, :_}, :_, :_, :_, :_, :_, :_},
      {{:functions, :_}, :_, :_, :_},
      {{:locations, :_}, :_, :_},
      {{:stacktrace_entries, :_}, :_, :_, :_, :_},
      {{:stacktraces, :_}, :_}
    ]
    |> Enum.each(fn item ->
      name = elem(elem(item, 0), 0)
      count = :ets.select_count(ets_table, [{item, [], [true]}])

      Logger.info("Preparing to dump #{count} #{name}")
    end)

    repo.delete_all(StacktraceEntry)
    repo.delete_all(Sample)
    repo.delete_all(Stacktrace)
    repo.delete_all(Function)
    repo.delete_all(Location)
    repo.delete_all(Query)

    insert_in_batches(repo, Query, queries_spec, ets_table)
    insert_in_batches(repo, Location, locations_spec, ets_table)
    insert_in_batches(repo, Function, functions_spec, ets_table)
    insert_in_batches(repo, Stacktrace, stacktraces_spec, ets_table)
    insert_in_batches(repo, Sample, samples_spec, ets_table)
    insert_in_batches(repo, StacktraceEntry, stacktrace_entries_spec, ets_table)

    Logger.info("Collected data is now available to query using #{repo} repo (#{repo.config()[:database]} database)")
  end

  def insert_in_batches(repo, schema, spec, ets_table) do
    result =
      if is_atom(ets_table) do
        :ets.select(ets_table, [spec], 1000)
      else
        :ets.select(ets_table)
      end

    case result do
      :"$end_of_table" ->
        :ok

      {items, :"$end_of_table"} ->
        Logger.info("Inserted #{length(items)} records into #{inspect(schema)}")
        repo.insert_all(schema, items)

      {items, cont} ->
        Logger.info("Inserted #{length(items)} records into #{inspect(schema)}")
        repo.insert_all(schema, items)
        insert_in_batches(repo, schema, spec, cont)
    end
  end
end

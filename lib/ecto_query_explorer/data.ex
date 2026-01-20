defmodule EctoQueryExplorer.Data do
  require Logger

  alias EctoQueryExplorer.{
    Epoch,
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
      select 'epochs' name, count(1) total_records from epochs
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
         where name in ('epochs', 'queries', 'samples', 'functions', 'locations', 'stacktrace_entries', 'stacktraces')
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
  Dumps ETS data to SQLite database.

  ## Options

    * `:epoch_name` - Name for this epoch (e.g., "abc123-api-6df6bd76f8-j8j6t")

  If not provided, defaults to HOSTNAME environment variable or "unknown".

  ## Examples

      EctoQueryExplorer.Data.dump2sqlite()
      EctoQueryExplorer.Data.dump2sqlite(epoch_name: "v1.2.3-pod-abc123")
  """
  def dump2sqlite(opts \\ []) do
    ets_table = Application.fetch_env!(:ecto_query_explorer, :ets_table_name)
    repo = Application.fetch_env!(:ecto_query_explorer, :repo)

    # Create epoch record
    epoch_id = create_epoch(repo, opts)
    Logger.info("Created epoch #{epoch_id}")

    queries_spec =
      {{{:queries, :"$1"}, :"$2", :"$3", :"$4", :"$5"}, [],
       [%{id: :"$1", text: :"$2", repo: :"$3", source: :"$4", counter: :"$5"}]}

    functions_spec =
      {{{:functions, :"$1"}, :"$2", :"$3", :"$4"}, [], [%{id: :"$1", module: :"$2", function: :"$3", arity: :"$4"}]}

    [
      {{:queries, :_}, :_, :_, :_, :_},
      {{:samples, :_}, :_, :_, :_, :_, :_, :_, :_},
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

    sqlite_params_limit = 32766

    # Tables without epoch_id (content-addressable)
    insert_in_batches(repo, Query, queries_spec, ets_table, div(sqlite_params_limit, 5))
    insert_in_batches(repo, Function, functions_spec, ets_table, div(sqlite_params_limit, 4))

    # Tables with epoch_id - need to add epoch_id during dump
    insert_locations_with_epoch(repo, ets_table, epoch_id, div(sqlite_params_limit, 4))
    insert_stacktraces_with_epoch(repo, ets_table, epoch_id, div(sqlite_params_limit, 3))
    insert_samples_with_epoch(repo, ets_table, epoch_id, div(sqlite_params_limit, 9))
    insert_stacktrace_entries(repo, ets_table, div(sqlite_params_limit, 5))

    Logger.info("Collected data is now available to query using #{repo} repo (#{repo.config()[:database]} database)")
  end

  defp create_epoch(repo, opts) do
    name = opts[:epoch_name] || System.get_env("HOSTNAME") || "unknown"

    {1, [%{id: epoch_id}]} =
      repo.insert_all(
        Epoch,
        [%{name: name, collected_at: DateTime.utc_now()}],
        returning: [:id]
      )

    epoch_id
  end

  defp insert_locations_with_epoch(repo, ets_table, epoch_id, batch_size) do
    spec = {{{:locations, :"$1"}, :"$2", :"$3"}, [], [%{id: :"$1", file: :"$2", line: :"$3"}]}

    insert_with_epoch(repo, Location, spec, ets_table, epoch_id, batch_size)
  end

  defp insert_stacktraces_with_epoch(repo, ets_table, epoch_id, batch_size) do
    spec = {{{:stacktraces, :"$1"}, :"$2"}, [], [%{id: :"$1", counter: :"$2"}]}

    insert_with_epoch(repo, Stacktrace, spec, ets_table, epoch_id, batch_size)
  end

  defp insert_samples_with_epoch(repo, ets_table, epoch_id, batch_size) do
    spec =
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

    insert_with_epoch(repo, Sample, spec, ets_table, epoch_id, batch_size)
  end

  defp insert_with_epoch(repo, schema, spec, ets_table, epoch_id, batch_size) do
    result =
      if is_atom(ets_table) do
        :ets.select(ets_table, [spec], batch_size)
      else
        :ets.select(ets_table)
      end

    do_insert_with_epoch(repo, schema, result, epoch_id, batch_size)
  end

  defp do_insert_with_epoch(_repo, _schema, :"$end_of_table", _epoch_id, _batch_size) do
    :ok
  end

  defp do_insert_with_epoch(repo, schema, {items, :"$end_of_table"}, epoch_id, _batch_size) do
    items_with_epoch = Enum.map(items, &Map.put(&1, :epoch_id, epoch_id))
    Logger.info("Inserted #{length(items_with_epoch)} records into #{inspect(schema)}")
    repo.insert_all(schema, items_with_epoch)
  end

  defp do_insert_with_epoch(repo, schema, {items, cont}, epoch_id, batch_size) do
    items_with_epoch = Enum.map(items, &Map.put(&1, :epoch_id, epoch_id))
    Logger.info("Inserted #{length(items_with_epoch)} records into #{inspect(schema)}")
    repo.insert_all(schema, items_with_epoch)
    do_insert_with_epoch(repo, schema, :ets.select(cont), epoch_id, batch_size)
  end

  defp insert_stacktrace_entries(repo, ets_table, batch_size) do
    spec =
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

    insert_in_batches(repo, StacktraceEntry, spec, ets_table, batch_size)
  end

  def insert_in_batches(repo, schema, spec, ets_table, batch_size) do
    result =
      if is_atom(ets_table) do
        :ets.select(ets_table, [spec], batch_size)
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
        insert_in_batches(repo, schema, spec, cont, batch_size)
    end
  end
end

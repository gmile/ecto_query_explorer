defmodule EctoQueryExplorer.Data do
  alias EctoQueryExplorer.{
    Query,
    Sample,
    Stacktrace,
    StacktraceEntry,
    Function,
    Location,
    Params
  }

  # change this to read configuration instead of passing parameters
  #
  def dump2sqlite(ets_table_name, repo) do
    table =
      if is_list(ets_table_name) do
        {:ok, table} = :ets.file2tab(ets_table_name)
        table
      else
        ets_table_name
      end

    queries_spec =
      {{{:queries, :"$1"}, :"$2", :"$3", :"$4", :"$5"}, [],
       [%{id: :"$1", text: :"$2", repo: :"$3", source: :"$4", counter: :"$5"}]}

    samples_spec =
      {{{:samples, :"$1"}, :"$2", :"$3", :"$4", :"$5", :"$6", :"$7"}, [],
       [
         %{
           id: :"$1",
           query_id: :"$2",
           total_time: :"$3",
           queue_time: :"$4",
           query_time: :"$5",
           decode_time: :"$6",
           stacktrace_id: :"$7"
         }
       ]}

    functions_spec =
      {{{:functions, :"$1"}, :"$2", :"$3", :"$4", :"$5"}, [],
       [%{id: :"$1", module: :"$2", function: :"$3", arity: :"$4", counter: :"$5"}]}

    locations_spec =
      {{{:locations, :"$1"}, :"$2", :"$3", :"$4"}, [],
       [%{id: :"$1", file: :"$2", line: :"$3", counter: :"$4"}]}

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

    params_spec =
      {{{:params, :"$1"}, :"$2"}, [], [:"$2"]}

    repo.delete_all(Params)
    repo.delete_all(StacktraceEntry)
    repo.delete_all(Sample)
    repo.delete_all(Stacktrace)
    repo.delete_all(Function)
    repo.delete_all(Location)
    repo.delete_all(Query)

    insert_in_batches(repo, Query, queries_spec, table)
    insert_in_batches(repo, Location, locations_spec, table)
    insert_in_batches(repo, Function, functions_spec, table)
    insert_in_batches(repo, Stacktrace, stacktraces_spec, table)
    insert_in_batches(repo, Sample, samples_spec, table)
    insert_in_batches(repo, StacktraceEntry, stacktrace_entries_spec, table)
    insert_params(repo, Params, params_spec, table)
  end

  def insert_params(repo, schema, spec, table) do
    :ets.select(table, [spec])
    |> List.flatten()
    |> Enum.chunk_every(1000)
    |> Enum.each(fn chunk ->
      data = Enum.map(chunk, fn {id, _, values} -> %{id: id, sample_id: id, values: values} end)
      repo.insert_all(schema, data)
    end)
  end

  def insert_in_batches(repo, schema, spec, table) do
    result =
      if is_atom(table) do
        :ets.select(table, [spec], 1000)
      else
        :ets.select(table)
      end

    case result do
      :"$end_of_table" ->
        :ok

      {items, :"$end_of_table"} ->
        repo.insert_all(schema, items)

      {items, cont} ->
        repo.insert_all(schema, items)
        insert_in_batches(repo, schema, spec, cont)
    end
  end
end

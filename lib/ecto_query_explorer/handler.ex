defmodule EctoQueryExplorer.Handler do
  @ignored_statements ~w(explain begin commit rollback)

  def handle_event(_, _, metadata, _, _) when metadata.query in @ignored_statements do
    :ok
  end

  # TODO: bring back counters
  #
  def handle_event(_event, measurements, metadata, config, %{sample_id: sample_id}) do
    text = metadata[:query]
    source = metadata[:source]
    repo = metadata[:repo] && to_string(metadata[:repo])
    stacktrace = metadata[:stacktrace]
    total_time = measurements[:total_time]
    decode_time = measurements[:decode_time]
    query_time = measurements[:query_time]
    queue_time = measurements[:queue_time]
    ets_table_name = config[:ets_table_name]
    samples_to_keep = config[:samples_to_keep]

    query_id = :erlang.phash2(text)

    unless :ets.insert_new(ets_table_name, {{:queries, query_id}, text, repo, source, 1}) do
      :ets.update_counter(ets_table_name, {:queries, query_id}, {5, 1})
    end

    stacktrace_id = :erlang.phash2(stacktrace)

    search = {{:samples, :_}, query_id, :_, :_, :_, :_, stacktrace_id}

    if :ets.select_count(ets_table_name, [{search, [], [true]}]) < samples_to_keep do
      sample =
        {{:samples, sample_id}, query_id, total_time, queue_time, query_time, decode_time,
         stacktrace_id}

      store_query_params(
        ets_table_name,
        query_id,
        metadata[:params],
        stacktrace_id,
        sample_id,
        total_time
      )

      :ets.insert_new(ets_table_name, sample)
    end

    # TODO:
    # if stacktrace is already known - do nothing

    unless :ets.insert_new(ets_table_name, {{:stacktraces, stacktrace_id}, 1}) do
      :ets.update_counter(ets_table_name, {:stacktraces, stacktrace_id}, {2, 1})
    end

    stacktrace
    |> List.wrap()
    |> Enum.with_index()
    |> Enum.each(fn {item, index} ->
      {module, function, arity, location} = item

      location_id =
        case location do
          [] ->
            nil

          [file: file, line: line] = value ->
            id = :erlang.phash2(value)

            :ets.insert_new(ets_table_name, {{:locations, id}, to_string(file), line})

            id
        end

      function_id = :erlang.phash2({module, function, arity})

      function = {{:functions, function_id}, to_string(module), to_string(function), arity}

      :ets.insert_new(ets_table_name, function)

      stacktrace_entry_id = :erlang.phash2({stacktrace_id, function_id, location_id, index})

      stacktrace_entry =
        {{:stacktrace_entries, stacktrace_entry_id}, stacktrace_id, function_id, location_id,
         index}

      :ets.insert_new(ets_table_name, stacktrace_entry)
    end)

    :ok
  end

  def store_query_params(ets_table_name, query_id, values, stacktrace_id, sample_id, total_time) do
    key = {:params, query_id, stacktrace_id}

    case :ets.lookup(ets_table_name, key) do
      [] ->
        :ets.insert_new(
          ets_table_name,
          {key, [{sample_id, total_time, :erlang.term_to_binary(values)}]}
        )

      [{^key, params}] ->
        new_list = [{sample_id, total_time, :erlang.term_to_binary(values)} | params]

        :ets.update_element(ets_table_name, key, {2, new_list})

      _ ->
        false
    end
  end
end

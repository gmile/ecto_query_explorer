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

    query_id = :erlang.phash2(text)

    unless :ets.insert_new(ets_table_name, {{:queries, query_id}, text, repo, source, 1}) do
      :ets.update_counter(ets_table_name, {:queries, query_id}, {5, 1})
    end

    stacktrace_id = :erlang.phash2(stacktrace)

    unless :ets.insert_new(ets_table_name, {{:stacktraces, stacktrace_id}, 1}) do
      :ets.update_counter(ets_table_name, {:stacktraces, stacktrace_id}, {2, 1})
    end

    sample =
      {{:samples, sample_id}, query_id, total_time, queue_time, query_time, decode_time,
       stacktrace_id}

    :ets.insert_new(ets_table_name, sample)

    store_query_params(ets_table_name, query_id, metadata[:params], sample_id, total_time)

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

            unless :ets.insert_new(ets_table_name, {{:locations, id}, to_string(file), line, 1}) do
              :ets.update_counter(ets_table_name, {:locations, id}, {4, 1})
            end

            id
        end

      function_id = :erlang.phash2({module, function, arity})

      function = {{:functions, function_id}, to_string(module), to_string(function), arity, 1}

      unless :ets.insert_new(ets_table_name, function) do
        :ets.update_counter(ets_table_name, {:functions, function_id}, {5, 1})
      end

      stacktrace_entry_id = :erlang.phash2({stacktrace_id, function_id, location_id, index})

      stacktrace_entry =
        {{:stacktrace_entries, stacktrace_entry_id}, stacktrace_id, function_id, location_id,
         index}

      :ets.insert_new(ets_table_name, stacktrace_entry)
    end)

    :ok
  end

  def store_query_params(ets_table_name, query_id, values, sample_id, total_time) do
    key = {:params, query_id}

    case :ets.lookup(ets_table_name, key) do
      [] ->
        :ets.insert_new(
          ets_table_name,
          {key, [{sample_id, total_time, :erlang.term_to_binary(values)}]}
        )

      [{^key, [{_sample_id, existing_total_time, _values} | _] = params}]
      when total_time > existing_total_time ->
        new_list =
          [{sample_id, total_time, :erlang.term_to_binary(values)} | params] |> Enum.take(3)

        :ets.update_element(ets_table_name, key, {2, new_list})

      _ ->
        false
    end
  end
end

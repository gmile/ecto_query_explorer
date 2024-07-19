defmodule EctoQueryExplorer.Handler do
  @ignored_statements ~w(explain begin commit rollback)

  def handle_event(_, _, metadata, _, _) when metadata.query in @ignored_statements do
    :ok
  end

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

    # counting samples per query/stacktrace
    counter_key = {:samples_count, query_id, stacktrace_id}

    sample_counter =
      if :ets.insert_new(ets_table_name, {counter_key, 1}) do
        1
      else
        :ets.update_counter(ets_table_name, counter_key, {2, 1})
      end

    sample =
      {{:samples, sample_id}, query_id, total_time, queue_time, query_time, decode_time,
       stacktrace_id, :erlang.term_to_binary(metadata[:params])}

    sample_cache_key = {:fastest_sample, query_id, stacktrace_id}

    if sample_counter <= samples_to_keep do
      # will insert only the first time for a given {query_id, stacktrace_id}
      :ets.insert_new(ets_table_name, {sample_cache_key, sample_id, total_time})

      match_spec = [
        {
          {sample_cache_key, :"$1", :"$2"},
          [{:>, :"$2", total_time}],
          [
            {
              {{sample_cache_key}, sample_id, total_time}
            }
          ]
        }
      ]

      :ets.select_replace(ets_table_name, match_spec)
      :ets.insert_new(ets_table_name, sample)
    else
      [{{:fastest_sample, _, _}, fastest_sample_id, fastest_total_time}] =
        :ets.lookup(ets_table_name, sample_cache_key)

      if fastest_total_time < total_time do
        # update cache
        :ets.insert(ets_table_name, {sample_cache_key, sample_id, total_time})

        # replace fastest sample with new sample
        :ets.delete(ets_table_name, {:samples, fastest_sample_id})
        :ets.insert_new(ets_table_name, sample)
      end
    end

    if :ets.insert_new(ets_table_name, {{:stacktraces, stacktrace_id}, 1}) do
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

      # insert all at once
    else
      :ets.update_counter(ets_table_name, {:stacktraces, stacktrace_id}, {2, 1})
    end

    :ok
  end
end

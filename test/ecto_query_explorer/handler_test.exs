defmodule EctoQueryExplorer.HandlerTest do
  use ExUnit.Case, async: true

  setup do
    :ets.new(:ecto_query_explorer_data, [:ordered_set, :named_table])

    :ok
  end

  describe "tracking query coming from the same stacktrace" do
    setup do
      metadata = %{
        params: [1, 2, 3],
        query: "select $1, $2, $3",
        repo: App.Repo,
        source: nil,
        stacktrace: [
          {Module1, :fun1, 1, [file: ~c"lib/path/to/file1.ex", line: 10]},
          {Module2, :fun2, 2, [file: ~c"lib/path/to/file2.ex", line: 20]},
          {Module3, :fun3, 3, [file: ~c"lib/path/to/file3.ex", line: 30]}
        ]
      }

      handle_event(%{total_time: 100}, metadata, 1)
      handle_event(%{total_time: 200}, metadata, 2)

      %{table: :ets.tab2list(:ecto_query_explorer_data)}
    end

    defp rows(table, key_part) do
      Enum.filter(table, fn row -> elem(elem(row, 0), 0) == key_part end)
    end

    test "records query only once, but updates counters", %{table: table} do
      assert [
               {{:queries, _id}, "select $1, $2, $3", "Elixir.App.Repo", nil, 2}
             ] = rows(table, :queries)
    end

    test "records a sample for each handle_event call, but updates counters", %{table: table} do
      assert [
               {{:samples, 1}, _, 100, nil, nil, nil, stacktrace_id, params},
               {{:samples, 2}, _, 200, nil, nil, nil, stacktrace_id, params}
             ] = rows(table, :samples)
    end

    test "records unique stacktrace entries only once", %{table: table} do
      assert [
               {{:stacktrace_entries, _id1}, _, _function_id1, _location_id1, 2},
               {{:stacktrace_entries, _id2}, _, _function_id2, _location_id2, 1},
               {{:stacktrace_entries, _id3}, _, _function_id3, _location_id3, 0}
             ] = rows(table, :stacktrace_entries)
    end

    test "records unique functions only once, but updates counters", %{table: table} do
      assert [
               {{:functions, _id1}, "Elixir.Module1", "fun1", 1},
               {{:functions, _id2}, "Elixir.Module3", "fun3", 3},
               {{:functions, _id3}, "Elixir.Module2", "fun2", 2}
             ] = rows(table, :functions)
    end

    test "records unique locations only once, but updates counters", %{table: table} do
      assert [
               {{:locations, _id1}, "lib/path/to/file2.ex", 20},
               {{:locations, _id2}, "lib/path/to/file3.ex", 30},
               {{:locations, _id3}, "lib/path/to/file1.ex", 10}
             ] = rows(table, :locations)
    end
  end

  describe "tracking same query coming from different stacktraces" do
    setup do
      metadata1 = %{
        params: [1, 2, 3],
        query: "select $1, $2, $3",
        repo: App.Repo,
        source: nil,
        stacktrace: [
          {Module1, :fun1, 1, [file: ~c"lib/path/to/file1.ex", line: 10]},
          {Module2, :fun2, 2, [file: ~c"lib/path/to/file2.ex", line: 20]},
          {Module3, :fun3, 3, [file: ~c"lib/path/to/file3.ex", line: 30]}
        ]
      }

      metadata2 = %{
        params: [1, 2, 3],
        query: "select $1, $2, $3",
        repo: App.Repo,
        source: nil,
        stacktrace: [
          {Module4, :fun4, 4, [file: ~c"lib/path/to/file4.ex", line: 40]},
          {Module5, :fun5, 5, [file: ~c"lib/path/to/file5.ex", line: 50]}
        ]
      }

      handle_event(%{total_time: 100}, metadata1, 1)
      handle_event(%{total_time: 200}, metadata2, 2)
      handle_event(%{total_time: 300}, metadata2, 3)

      %{table: :ets.tab2list(:ecto_query_explorer_data)}
    end

    test "records query only once, but updates counters", %{table: table} do
      assert [
               {{:queries, _id}, "select $1, $2, $3", "Elixir.App.Repo", nil, 3}
             ] = rows(table, :queries)
    end

    test "records a sample for each handle_event call, but updates counters", %{table: table} do
      assert [
               {{:samples, 1}, query_id, 100, nil, nil, nil, _stacktrace_id1, params},
               {{:samples, 2}, query_id, 200, nil, nil, nil, stacktrace_id2, params},
               {{:samples, 3}, query_id, 300, nil, nil, nil, stacktrace_id2, params}
             ] = rows(table, :samples)
    end

    test "records unique stacktrace entries only once", %{table: table} do
      assert [
               {{:stacktrace_entries, 3_674_573}, stacktrace_id1, 45_027_181, 130_350_853, 0},
               {{:stacktrace_entries, 8_843_864}, stacktrace_id2, 19_952_418, 87_370_938, 2},
               {{:stacktrace_entries, 59_766_192}, stacktrace_id2, 113_137_910, 52_641_331, 1},
               {{:stacktrace_entries, 70_829_290}, stacktrace_id1, 22_371_231, 15_256_582, 1},
               {{:stacktrace_entries, 90_748_837}, stacktrace_id2, 17_298_056, 90_889_579, 0}
             ] = rows(table, :stacktrace_entries)
    end

    test "records unique function only once", %{table: table} do
      assert [
               {{:functions, _function_id1}, "Elixir.Module1", "fun1", 1},
               {{:functions, _function_id2}, "Elixir.Module3", "fun3", 3},
               {{:functions, _function_id3}, "Elixir.Module5", "fun5", 5},
               {{:functions, _function_id4}, "Elixir.Module4", "fun4", 4},
               {{:functions, _function_id5}, "Elixir.Module2", "fun2", 2}
             ] = rows(table, :functions)
    end

    test "records unique locations only once", %{table: table} do
      assert [
               {{:locations, _location_id1}, "lib/path/to/file5.ex", 50},
               {{:locations, _location_id2}, "lib/path/to/file2.ex", 20},
               {{:locations, _location_id3}, "lib/path/to/file3.ex", 30},
               {{:locations, _location_id4}, "lib/path/to/file1.ex", 10},
               {{:locations, _location_id5}, "lib/path/to/file4.ex", 40}
             ] = rows(table, :locations)
    end
  end

  describe "tracking different queries coming from different locations" do
    setup do
      metadata1 = %{
        params: [1, 2],
        query: "select $1, $2",
        repo: App.Repo,
        source: nil,
        stacktrace: [
          {Module1, :fun1, 1, [file: ~c"lib/path/to/file1.ex", line: 10]},
          {Module2, :fun2, 2, [file: ~c"lib/path/to/file2.ex", line: 20]},
          {Module3, :fun3, 3, [file: ~c"lib/path/to/file3.ex", line: 30]}
        ]
      }

      metadata2 = %{
        params: [1, 2, 3],
        query: "select $1, $2, $3",
        repo: App.Repo,
        source: nil,
        stacktrace: [
          {Module4, :fun4, 4, [file: ~c"lib/path/to/file4.ex", line: 40]},
          {Module5, :fun5, 5, [file: ~c"lib/path/to/file5.ex", line: 50]}
        ]
      }

      handle_event(%{total_time: 100}, metadata1, 1)
      handle_event(%{total_time: 200}, metadata2, 2)

      %{table: :ets.tab2list(:ecto_query_explorer_data)}
    end

    test "records query only once, but updates counters", %{table: table} do
      assert [
               {{:queries, _}, "select $1, $2", "Elixir.App.Repo", nil, 1},
               {{:queries, _}, "select $1, $2, $3", "Elixir.App.Repo", nil, 1}
             ] = rows(table, :queries)
    end

    test "records a sample for each handle_event call, but updates counters", %{table: table} do
      assert [
               {{:samples, 1}, _, 100, nil, nil, nil, _stacktrace_id1, _params1},
               {{:samples, 2}, _, 200, nil, nil, nil, _stacktrace_id2, _params2}
             ] = rows(table, :samples)
    end

    test "records unique stacktrace entries only once", %{table: table} do
      assert [
               {{:stacktrace_entries, _}, stacktrace_id1, _, _, 0},
               {{:stacktrace_entries, _}, stacktrace_id2, _, _, 2},
               {{:stacktrace_entries, _}, stacktrace_id2, _, _, 1},
               {{:stacktrace_entries, _}, stacktrace_id1, _, _, 1},
               {{:stacktrace_entries, _}, stacktrace_id2, _, _, 0}
             ] = rows(table, :stacktrace_entries)
    end

    test "records unique functions only once, but updates counters", %{table: table} do
      assert [
               {{:functions, _}, "Elixir.Module1", "fun1", 1},
               {{:functions, _}, "Elixir.Module3", "fun3", 3},
               {{:functions, _}, "Elixir.Module5", "fun5", 5},
               {{:functions, _}, "Elixir.Module4", "fun4", 4},
               {{:functions, _}, "Elixir.Module2", "fun2", 2}
             ] = rows(table, :functions)
    end

    test "records unique locations only once, but updates counters", %{table: table} do
      assert [
               {{:locations, _}, "lib/path/to/file5.ex", 50},
               {{:locations, _}, "lib/path/to/file2.ex", 20},
               {{:locations, _}, "lib/path/to/file3.ex", 30},
               {{:locations, _}, "lib/path/to/file1.ex", 10},
               {{:locations, _}, "lib/path/to/file4.ex", 40}
             ] = rows(table, :locations)
    end
  end

  # Scenario, in which we deployed code change (like moving the code),
  # so the query is coming from the same MFA, but different locations in code.
  #
  describe "tracking same query coming from same mfa, but different locations" do
    setup do
      metadata1 = %{
        params: [1, 2],
        query: "select $1, $2",
        repo: App.Repo,
        source: nil,
        stacktrace: [
          {Module1, :fun1, 1, [file: ~c"lib/path/to/file1.ex", line: 10]},
          {Module2, :fun2, 2, [file: ~c"lib/path/to/file2.ex", line: 20]},
          {Module3, :fun3, 3, [file: ~c"lib/path/to/file3.ex", line: 30]}
        ]
      }

      metadata2 = %{
        params: [1, 2],
        query: "select $1, $2",
        repo: App.Repo,
        source: nil,
        stacktrace: [
          {Module1, :fun1, 1, [file: ~c"lib/path/to/file1.ex", line: 10]},
          {Module2, :fun2, 2, [file: ~c"lib/path/to/file2.ex", line: 25]},
          {Module3, :fun3, 3, [file: ~c"lib/path/to/file3.ex", line: 30]}
        ]
      }

      handle_event(%{total_time: 100}, metadata1, 1)
      handle_event(%{total_time: 200}, metadata2, 2)

      %{table: :ets.tab2list(:ecto_query_explorer_data)}
    end

    test "records query only once, but updates counters", %{table: table} do
      assert [
               {{:queries, _}, "select $1, $2", "Elixir.App.Repo", nil, 2}
             ] = rows(table, :queries)
    end

    test "records a sample for each handle_event call, but updates counters", %{table: table} do
      assert [
               {{:samples, 1}, _, 100, nil, nil, nil, _stacktrace_id1, params},
               {{:samples, 2}, _, 200, nil, nil, nil, _stacktrace_id2, params}
             ] = rows(table, :samples)
    end

    test "records unique stacktrace entries only once", %{table: table} do
      assert [
               {{:stacktrace_entries, _}, stacktrace_id1, _, _, 2},
               {{:stacktrace_entries, _}, stacktrace_id2, _, _, 1},
               {{:stacktrace_entries, _}, stacktrace_id1, _, _, 1},
               {{:stacktrace_entries, _}, stacktrace_id1, _, _, 0},
               {{:stacktrace_entries, _}, stacktrace_id2, _, _, 0},
               {{:stacktrace_entries, _}, stacktrace_id2, _, _, 2}
             ] = rows(table, :stacktrace_entries)
    end

    test "records unique functions only once, but updates counters", %{table: table} do
      assert [
               {{:functions, _}, "Elixir.Module1", "fun1", 1},
               {{:functions, _}, "Elixir.Module3", "fun3", 3},
               {{:functions, _}, "Elixir.Module2", "fun2", 2}
             ] = rows(table, :functions)
    end

    test "records unique locations only once, but updates counters", %{table: table} do
      assert [
               {{:locations, 44_059_840}, "lib/path/to/file2.ex", 25},
               {{:locations, 52_641_331}, "lib/path/to/file2.ex", 20},
               {{:locations, 87_370_938}, "lib/path/to/file3.ex", 30},
               {{:locations, 90_889_579}, "lib/path/to/file1.ex", 10}
             ] = rows(table, :locations)
    end
  end

  # This happens in cases when query:
  #
  # 1. is built dynamically,
  # 2. there was a refactoring, and same place in code now emits completely
  #    different query.
  #
  describe "tracking different queries coming from same stacktrace" do
    setup do
      metadata1 = %{
        params: [1, 2],
        query: "select $1, $2",
        repo: App.Repo,
        source: nil,
        stacktrace: [
          {Module1, :fun1, 1, [file: ~c"lib/path/to/file1.ex", line: 10]},
          {Module2, :fun2, 2, [file: ~c"lib/path/to/file2.ex", line: 20]},
          {Module3, :fun3, 3, [file: ~c"lib/path/to/file3.ex", line: 30]}
        ]
      }

      metadata2 = %{
        params: [1, 2, 3],
        query: "select $1, $2, $3",
        repo: App.Repo,
        source: nil,
        stacktrace: [
          {Module1, :fun1, 1, [file: ~c"lib/path/to/file1.ex", line: 10]},
          {Module2, :fun2, 2, [file: ~c"lib/path/to/file2.ex", line: 20]},
          {Module3, :fun3, 3, [file: ~c"lib/path/to/file3.ex", line: 30]}
        ]
      }

      handle_event(%{total_time: 100}, metadata1, 1)
      handle_event(%{total_time: 200}, metadata2, 2)

      %{table: :ets.tab2list(:ecto_query_explorer_data)}
    end

    test "records query only once, but updates counters", %{table: table} do
      assert [
               {{:queries, _}, "select $1, $2", "Elixir.App.Repo", nil, 1},
               {{:queries, _}, "select $1, $2, $3", "Elixir.App.Repo", nil, 1}
             ] = rows(table, :queries)
    end

    test "records a sample for each handle_event call, but updates counters", %{table: table} do
      assert [
               {{:samples, 1}, _, 100, nil, nil, nil, _stacktrace_id1, _params1},
               {{:samples, 2}, _, 200, nil, nil, nil, _stacktrace_id2, _params2}
             ] = rows(table, :samples)
    end

    test "records unique stacktrace entries only once", %{table: table} do
      assert [
               {{:stacktrace_entries, _}, stacktrace_id, _, _, 2},
               {{:stacktrace_entries, _}, stacktrace_id, _, _, 1},
               {{:stacktrace_entries, _}, stacktrace_id, _, _, 0}
             ] = rows(table, :stacktrace_entries)
    end

    test "records unique functions only once, but updates counters", %{table: table} do
      assert [
               {{:functions, _}, "Elixir.Module1", "fun1", 1},
               {{:functions, _}, "Elixir.Module3", "fun3", 3},
               {{:functions, _}, "Elixir.Module2", "fun2", 2}
             ] = rows(table, :functions)
    end

    test "records unique locations only once, but updates counters", %{table: table} do
      assert [
               {{:locations, _}, "lib/path/to/file2.ex", 20},
               {{:locations, _}, "lib/path/to/file3.ex", 30},
               {{:locations, _}, "lib/path/to/file1.ex", 10}
             ] = rows(table, :locations)
    end
  end

  describe "tracking different queries, when some locations overlap" do
    setup do
      metadata1 = %{
        params: [1, 2],
        query: "select $1, $2",
        repo: App.Repo,
        source: nil,
        stacktrace: [
          {Module1, :fun1, 1, [file: ~c"lib/path/to/file1.ex", line: 10]},
          {Module2, :fun2, 2, [file: ~c"lib/path/to/file2.ex", line: 20]},
          {Module3, :fun3, 3, [file: ~c"lib/path/to/file3.ex", line: 30]}
        ]
      }

      metadata2 = %{
        params: [1, 2, 3],
        query: "select $1, $2, $3",
        repo: App.Repo,
        source: nil,
        stacktrace: [
          {Module1, :fun1, 1, [file: ~c"lib/path/to/file1.ex", line: 10]},
          {Module2, :fun2, 2, [file: ~c"lib/path/to/file2.ex", line: 20]},
          {Module4, :fun4, 4, [file: ~c"lib/path/to/file4.ex", line: 40]}
        ]
      }

      handle_event(%{total_time: 100}, metadata1, 1)
      handle_event(%{total_time: 200}, metadata2, 2)

      %{table: :ets.tab2list(:ecto_query_explorer_data)}
    end

    test "records query only once, but updates counters", %{table: table} do
      assert [
               {{:queries, _}, "select $1, $2", "Elixir.App.Repo", nil, 1},
               {{:queries, _}, "select $1, $2, $3", "Elixir.App.Repo", nil, 1}
             ] = rows(table, :queries)
    end

    test "records a sample for each handle_event call, but updates counters", %{table: table} do
      assert [
               {{:samples, 1}, _, 100, nil, nil, nil, _stacktrace_id1, _params1},
               {{:samples, 2}, _, 200, nil, nil, nil, _stacktrace_id2, _params2}
             ] = rows(table, :samples)
    end

    test "records unique stacktrace entries only once", %{table: table} do
      assert [
               {{:stacktrace_entries, _}, _, _, _, 2},
               {{:stacktrace_entries, _}, _, _, _, 0},
               {{:stacktrace_entries, _}, _, _, _, 1},
               {{:stacktrace_entries, _}, _, _, _, 1},
               {{:stacktrace_entries, _}, _, _, _, 0},
               {{:stacktrace_entries, _}, _, _, _, 2}
             ] = rows(table, :stacktrace_entries)
    end

    test "records unique functions only once, but updates counters", %{table: table} do
      assert [
               {{:functions, _}, "Elixir.Module1", "fun1", 1},
               {{:functions, _}, "Elixir.Module3", "fun3", 3},
               {{:functions, _}, "Elixir.Module4", "fun4", 4},
               {{:functions, _}, "Elixir.Module2", "fun2", 2}
             ] = rows(table, :functions)
    end

    test "records unique locations only once, but updates counters", %{table: table} do
      assert [
               {{:locations, _}, "lib/path/to/file2.ex", 20},
               {{:locations, _}, "lib/path/to/file3.ex", 30},
               {{:locations, _}, "lib/path/to/file1.ex", 10},
               {{:locations, _}, "lib/path/to/file4.ex", 40}
             ] = rows(table, :locations)
    end
  end

  describe "stores query params" do
    test "for 3 first samples per query and stacktrace pair" do
      metadata1 = %{
        params: [1, 2],
        query: "select $1, $2",
        repo: App.Repo,
        source: nil,
        stacktrace: [
          {Module1, :fun1, 1, [file: ~c"lib/path/to/file1.ex", line: 10]},
          {Module2, :fun2, 2, [file: ~c"lib/path/to/file2.ex", line: 20]},
          {Module3, :fun3, 3, [file: ~c"lib/path/to/file3.ex", line: 30]}
        ]
      }

      metadata2 = %{
        params: [1, 2],
        query: "select $1, $2",
        repo: App.Repo,
        source: nil,
        stacktrace: [
          {Module1, :fun1, 1, [file: ~c"lib/path/to/file1.ex", line: 10]},
          {Module2, :fun2, 2, [file: ~c"lib/path/to/file2.ex", line: 20]},
          {Module4, :fun4, 4, [file: ~c"lib/path/to/file4.ex", line: 40]}
        ]
      }

      metadata3 = %{
        params: [1, 2],
        query: "select $1, $2, $3",
        repo: App.Repo,
        source: nil,
        stacktrace: [
          {Module1, :fun1, 1, [file: ~c"lib/path/to/file1.ex", line: 10]},
          {Module2, :fun2, 2, [file: ~c"lib/path/to/file2.ex", line: 20]},
          {Module4, :fun4, 4, [file: ~c"lib/path/to/file4.ex", line: 40]}
        ]
      }

      handle_event(%{total_time: 8}, metadata1, 1)
      handle_event(%{total_time: 9}, metadata1, 2)
      handle_event(%{total_time: 10}, metadata1, 3)
      handle_event(%{total_time: 11}, metadata1, 4)

      handle_event(%{total_time: 7}, metadata2, 5)
      handle_event(%{total_time: 8}, metadata2, 6)
      handle_event(%{total_time: 9}, metadata2, 7)
      handle_event(%{total_time: 10}, metadata2, 8)

      handle_event(%{total_time: 6}, metadata3, 9)
      handle_event(%{total_time: 7}, metadata3, 10)
      handle_event(%{total_time: 8}, metadata3, 11)
      handle_event(%{total_time: 9}, metadata3, 12)

      assert [_] = :ets.lookup(:ecto_query_explorer_data, {:samples, 1})
      assert [_] = :ets.lookup(:ecto_query_explorer_data, {:samples, 2})
      assert [_] = :ets.lookup(:ecto_query_explorer_data, {:samples, 3})
      assert [] = :ets.lookup(:ecto_query_explorer_data, {:samples, 4})

      assert [_] = :ets.lookup(:ecto_query_explorer_data, {:samples, 5})
      assert [_] = :ets.lookup(:ecto_query_explorer_data, {:samples, 6})
      assert [_] = :ets.lookup(:ecto_query_explorer_data, {:samples, 7})
      assert [] = :ets.lookup(:ecto_query_explorer_data, {:samples, 8})

      assert [_] = :ets.lookup(:ecto_query_explorer_data, {:samples, 9})
      assert [_] = :ets.lookup(:ecto_query_explorer_data, {:samples, 10})
      assert [_] = :ets.lookup(:ecto_query_explorer_data, {:samples, 11})
      assert [] = :ets.lookup(:ecto_query_explorer_data, {:samples, 12})
    end
  end

  defp handle_event(measurements, metadata, sample_id) do
    EctoQueryExplorer.Handler.handle_event(
      "any-name",
      measurements,
      metadata,
      [repo: Repo, ets_table_name: :ecto_query_explorer_data, samples_to_keep: 3],
      %{sample_id: sample_id}
    )
  end

  # test these scenarios for stacktraces:

  #   |  
  #   |  
  #  / \
  # |   |
  #
  #
  # \   /
  #  \ /
  #   |  
  #   |  

  # \   /
  #  \ /
  #   |  
  #   |  
  #  / \
  # |   |

  #   |  
  #   |  
  #  / \
  # |   |
  # \   /
  #  \ /
  #   |  
  #   |  
end

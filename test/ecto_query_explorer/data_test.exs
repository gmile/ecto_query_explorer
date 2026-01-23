defmodule EctoQueryExplorer.DataTest do
  use ExUnit.Case, async: true

  import Ecto.Query

  alias EctoQueryExplorer.{Dump, Query}
  alias EctoQueryExplorer.TestRepo, as: Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    Application.put_env(:ecto_query_explorer, :ets_table_name, :testing_data_dump)
    Application.put_env(:ecto_query_explorer, :repo, Repo)

    :ets.new(:testing_data_dump, [:ordered_set, :named_table, :public])

    :ok
  end

  describe "ets_stats/0" do
    test "prints ETS statistics" do
      create_query()

      assert %{
               total_records: 21,
               total_memory: _
             } = EctoQueryExplorer.Data.ets_stats()
    end
  end

  describe "repo_stats/0" do
    test "prints repo statistics" do
      assert %Exqlite.Result{
               command: :execute,
               columns: ["name", "total_records", "bytes"],
               rows: [
                 ["dumps", 0, 4096],
                 ["functions", 0, 4096],
                 ["locations", 0, 4096],
                 ["queries", 0, 4096],
                 ["samples", 0, 4096],
                 ["stacktrace_entries", 0, 4096],
                 ["stacktraces", 0, 4096]
               ],
               num_rows: 7
             } == EctoQueryExplorer.Data.repo_stats()

      create_query()
      EctoQueryExplorer.Data.dump2sqlite()

      assert %Exqlite.Result{
               command: :execute,
               columns: ["name", "total_records", "bytes"],
               rows: [
                 ["dumps", 1, 4096],
                 ["functions", 6, 4096],
                 ["locations", 6, 4096],
                 ["queries", 1, 4096],
                 ["samples", 1, 4096],
                 ["stacktrace_entries", 6, 4096],
                 ["stacktraces", 1, 4096]
               ],
               num_rows: 7
             } == EctoQueryExplorer.Data.repo_stats()

      EctoQueryExplorer.Data.repo_stats()
    end
  end

  describe "dumps" do
    test "creates dump with default name" do
      create_query()
      EctoQueryExplorer.Data.dump2sqlite()

      dump = Repo.one(Dump)
      assert dump.name == "1"
      assert dump.collected_at != nil
    end

    test "creates dump with custom name" do
      create_query()
      EctoQueryExplorer.Data.dump2sqlite(name: "my-custom-dump")

      dump = Repo.one(Dump)
      assert dump.name == "my-custom-dump"
    end

    test "associates dump_id with locations, stacktraces, and samples" do
      create_query()
      EctoQueryExplorer.Data.dump2sqlite(name: "test-dump")

      dump = Repo.one(Dump)

      # Check locations have dump_id
      locations = Repo.all(EctoQueryExplorer.Location)
      assert Enum.all?(locations, &(&1.dump_id == dump.id))

      # Check stacktraces have dump_id
      stacktraces = Repo.all(EctoQueryExplorer.Stacktrace)
      assert Enum.all?(stacktraces, &(&1.dump_id == dump.id))

      # Check samples have dump_id
      samples = Repo.all(EctoQueryExplorer.Sample)
      assert Enum.all?(samples, &(&1.dump_id == dump.id))

      # Check queries and functions do NOT have dump_id (content-addressable)
      queries = Repo.all(EctoQueryExplorer.Query)
      assert Enum.all?(queries, &(not Map.has_key?(&1, :dump_id)))

      functions = Repo.all(EctoQueryExplorer.Function)
      assert Enum.all?(functions, &(not Map.has_key?(&1, :dump_id)))
    end

    test "data accumulates across dumps: same dump = no ETS reset, new dump = ETS reset" do
      # Pod 1: first dump
      insert_minimal_query(1, "query-1", counter: 5)
      EctoQueryExplorer.Data.dump2sqlite(name: "pod-1")
      assert_queries(%{1 => 5})

      # Pod 1: second dump (no ETS reset, counter updates)
      insert_minimal_query(2, "query-2", counter: 3)
      update_query_counter(1, 10)
      EctoQueryExplorer.Data.dump2sqlite(name: "pod-1")
      assert_queries(%{1 => 10, 2 => 3})

      # Pod 2: first dump (ETS reset, new queries)
      :ets.delete_all_objects(:testing_data_dump)
      insert_minimal_query(3, "query-3", counter: 7)
      EctoQueryExplorer.Data.dump2sqlite(name: "pod-2")
      assert_queries(%{1 => 10, 2 => 3, 3 => 7})

      # Pod 2: second dump (no ETS reset, counter updates)
      insert_minimal_query(4, "query-4", counter: 2)
      update_query_counter(3, 15)
      EctoQueryExplorer.Data.dump2sqlite(name: "pod-2")
      assert_queries(%{1 => 10, 2 => 3, 3 => 15, 4 => 2})

      # Pod 3: single dump (ETS reset)
      :ets.delete_all_objects(:testing_data_dump)
      insert_minimal_query(5, "query-5", counter: 100)
      EctoQueryExplorer.Data.dump2sqlite(name: "pod-3")
      assert_queries(%{1 => 10, 2 => 3, 3 => 15, 4 => 2, 5 => 100})

      # Dump names are unique - subsequent dumps with same name reuse existing record
      assert ["pod-1", "pod-2", "pod-3"] ==
               Repo.all(from(e in Dump, select: e.name, order_by: e.id))
    end
  end

  describe "dumps stacktraces data correctly" do
    test "query and all related entities are connected and dumped correctly" do
      :ets.insert_new(:testing_data_dump, [
        {{:functions, 10_545_222}, "Elixir.Ecto.Repo.Supervisor", "tuplet", 2},
        {{:functions, 13_607_698}, "gen_server", "init_it", 6},
        {{:functions, 45_708_481}, "Elixir.App.Repo", "all", 2},
        {{:functions, 68_908_858}, "gen_server", "init_it", 2},
        {{:functions, 79_772_134}, "proc_lib", "init_p_do_apply", 3},
        {{:functions, 113_359_675}, "Elixir.App.CodeModule", "init", 1},
        {{:locations, 30_117_895}, "lib/my_app/path/to/code/module.ex", 12},
        {{:locations, 30_369_914}, "lib/my_app/repo.ex", 2},
        {{:locations, 61_301_931}, "proc_lib.erl", 240},
        {{:locations, 82_329_887}, "gen_server.erl", 851},
        {{:locations, 87_052_619}, "gen_server.erl", 814},
        {{:locations, 110_342_722}, "lib/ecto/repo/supervisor.ex", 163},
        {{:queries, 129_284_157}, "select * from customers where id = $1", "App.Repo", "customers", 1},
        {{:samples, 123}, 129_284_157, 3_271_209, 2_322_375, 944_584, 4250, 59_205_549, <<131, 107, 0, 1, 234>>},
        {{:stacktrace_entries, 12_081_283}, 59_205_549, 79_772_134, 61_301_931, 5},
        {{:stacktrace_entries, 30_562_826}, 59_205_549, 68_908_858, 82_329_887, 3},
        {{:stacktrace_entries, 64_780_584}, 59_205_549, 13_607_698, 87_052_619, 4},
        {{:stacktrace_entries, 89_105_269}, 59_205_549, 10_545_222, 110_342_722, 0},
        {{:stacktrace_entries, 98_253_173}, 59_205_549, 113_359_675, 30_117_895, 2},
        {{:stacktrace_entries, 119_695_449}, 59_205_549, 45_708_481, 30_369_914, 1},
        {{:stacktraces, 59_205_549}, 1}
      ])

      EctoQueryExplorer.Data.dump2sqlite()

      query =
        Repo.one(
          from(q in Query,
            join: s in assoc(q, :samples),
            join: st in assoc(s, :stacktrace),
            join: se in assoc(st, :stacktrace_entries),
            join: f in assoc(se, :function),
            join: l in assoc(se, :location),
            preload: [
              samples:
                {s,
                 [
                   stacktrace: {st, [stacktrace_entries: {se, [function: f, location: l]}]}
                 ]}
            ],
            order_by: {:asc, se.index}
          )
        )

      encoded_params = :erlang.term_to_binary([234])

      assert %{
               text: "select * from customers where id = $1",
               samples: [
                 %{
                   id: 123,
                   decode_time: 4250,
                   query_time: 944_584,
                   queue_time: 2_322_375,
                   total_time: 3_271_209,
                   params: ^encoded_params,
                   stacktrace: %{
                     id: 59_205_549,
                     counter: 1,
                     stacktrace_entries: [
                       %{
                         index: 0,
                         function: %{
                           module: "Elixir.Ecto.Repo.Supervisor",
                           function: "tuplet",
                           arity: 2
                         },
                         location: %{
                           file: "lib/ecto/repo/supervisor.ex",
                           line: 163
                         }
                       },
                       %{
                         index: 1,
                         function: %{
                           module: "Elixir.App.Repo",
                           function: "all",
                           arity: 2
                         },
                         location: %{
                           file: "lib/my_app/repo.ex",
                           line: 2
                         }
                       },
                       %{
                         index: 2,
                         function: %{
                           module: "Elixir.App.CodeModule",
                           function: "init",
                           arity: 1
                         },
                         location: %{
                           file: "lib/my_app/path/to/code/module.ex",
                           line: 12
                         }
                       },
                       %{
                         index: 3,
                         function: %{
                           module: "gen_server",
                           function: "init_it",
                           arity: 2
                         },
                         location: %{
                           file: "gen_server.erl",
                           line: 851
                         }
                       },
                       %{
                         index: 4,
                         function: %{
                           module: "gen_server",
                           function: "init_it",
                           arity: 6
                         },
                         location: %{
                           file: "gen_server.erl",
                           line: 814
                         }
                       },
                       %{
                         index: 5,
                         function: %{
                           module: "proc_lib",
                           function: "init_p_do_apply",
                           arity: 3
                         },
                         location: %{
                           file: "proc_lib.erl",
                           line: 240
                         }
                       }
                     ]
                   }
                 }
               ]
             } = query
    end
  end

  defp create_query do
    :ets.insert_new(:testing_data_dump, [
      {{:functions, 10_545_222}, "Elixir.Ecto.Repo.Supervisor", "tuplet", 2},
      {{:functions, 13_607_698}, "gen_server", "init_it", 6},
      {{:functions, 45_708_481}, "Elixir.App.Repo", "all", 2},
      {{:functions, 68_908_858}, "gen_server", "init_it", 2},
      {{:functions, 79_772_134}, "proc_lib", "init_p_do_apply", 3},
      {{:functions, 113_359_675}, "Elixir.App.CodeModule", "init", 1},
      {{:locations, 30_117_895}, "lib/my_app/path/to/code/module.ex", 12},
      {{:locations, 30_369_914}, "lib/my_app/repo.ex", 2},
      {{:locations, 61_301_931}, "proc_lib.erl", 240},
      {{:locations, 82_329_887}, "gen_server.erl", 851},
      {{:locations, 87_052_619}, "gen_server.erl", 814},
      {{:locations, 110_342_722}, "lib/ecto/repo/supervisor.ex", 163},
      {{:queries, 129_284_157}, "select * from customers where id = $1",
       "Elixir.EctoQueryExplorer.QueriesTest.App.Repo", "customers", 1},
      {{:samples, 123}, 129_284_157, 3_271_209, 2_322_375, 944_584, 4250, 59_205_549, <<131, 107, 0, 1, 234>>},
      {{:stacktrace_entries, 12_081_283}, 59_205_549, 79_772_134, 61_301_931, 5},
      {{:stacktrace_entries, 30_562_826}, 59_205_549, 68_908_858, 82_329_887, 3},
      {{:stacktrace_entries, 64_780_584}, 59_205_549, 13_607_698, 87_052_619, 4},
      {{:stacktrace_entries, 89_105_269}, 59_205_549, 10_545_222, 110_342_722, 0},
      {{:stacktrace_entries, 98_253_173}, 59_205_549, 113_359_675, 30_117_895, 2},
      {{:stacktrace_entries, 119_695_449}, 59_205_549, 45_708_481, 30_369_914, 1},
      {{:stacktraces, 59_205_549}, 1}
    ])
  end

  defp insert_minimal_query(id, text, opts) do
    func_id = id * 10 + 1
    loc_id = id * 10 + 2
    st_id = id * 10 + 3
    ste_id = id * 10 + 4
    counter = Keyword.get(opts, :counter, 1)

    :ets.insert_new(:testing_data_dump, [
      {{:functions, func_id}, "Mod#{id}", "func", 1},
      {{:locations, loc_id}, "lib/mod#{id}.ex", id},
      {{:queries, id}, text, "App.Repo", "table", counter},
      {{:samples, id}, id, 1000, 100, 800, 100, st_id, <<131, 106>>},
      {{:stacktrace_entries, ste_id}, st_id, func_id, loc_id, 0},
      {{:stacktraces, st_id}, 1}
    ])
  end

  defp update_query_counter(id, new_counter) do
    [{key, text, repo, source, _old_counter}] = :ets.lookup(:testing_data_dump, {:queries, id})
    :ets.insert(:testing_data_dump, {key, text, repo, source, new_counter})
  end

  defp assert_queries(expected) do
    actual =
      Repo.all(from(q in Query, select: {q.id, q.counter}))
      |> Map.new()

    assert expected == actual
  end
end

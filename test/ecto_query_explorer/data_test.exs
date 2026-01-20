defmodule EctoQueryExplorer.DataTest do
  use ExUnit.Case, async: true

  import Ecto.Query

  alias EctoQueryExplorer.{Epoch, Query}

  defmodule Repo do
    use Ecto.Repo,
      adapter: Ecto.Adapters.SQLite3,
      otp_app: :my_app,
      warn: false
  end

  setup do
    Application.put_all_env(
      ecto_query_explorer: [
        ets_table_name: :testing_data_dump,
        repo: Repo
      ]
    )

    :ets.new(:testing_data_dump, [:ordered_set, :named_table])

    Application.put_env(:my_app, Repo,
      database: ":memory:",
      pool: Ecto.Adapters.SQL.Sandbox,
      pool_size: 1
    )

    Repo.__adapter__().storage_up(Repo.config())

    {:ok, _pid} = Repo.start_link()

    :ok = Ecto.Adapters.SQL.Sandbox.mode(Repo, :manual)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    Ecto.Migrator.run(Repo, [{0, EctoQueryExplorer.Migration0}, {1, EctoQueryExplorer.Migration1}], :up,
      all: true,
      log_migrations_sql: :debug
    )

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
                 ["epochs", 0, 4096],
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
                 ["epochs", 1, 4096],
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

  describe "epochs" do
    test "creates epoch with default name from HOSTNAME" do
      System.put_env("HOSTNAME", "test-pod-abc123")

      create_query()
      EctoQueryExplorer.Data.dump2sqlite()

      epoch = Repo.one(Epoch)
      assert epoch.name == "test-pod-abc123"
      assert epoch.collected_at != nil

      System.delete_env("HOSTNAME")
    end

    test "creates epoch with custom name" do
      create_query()
      EctoQueryExplorer.Data.dump2sqlite(epoch_name: "my-custom-epoch")

      epoch = Repo.one(Epoch)
      assert epoch.name == "my-custom-epoch"
    end

    test "associates epoch_id with locations, stacktraces, and samples" do
      create_query()
      EctoQueryExplorer.Data.dump2sqlite(epoch_name: "test-epoch")

      epoch = Repo.one(Epoch)

      # Check locations have epoch_id
      locations = Repo.all(EctoQueryExplorer.Location)
      assert Enum.all?(locations, &(&1.epoch_id == epoch.id))

      # Check stacktraces have epoch_id
      stacktraces = Repo.all(EctoQueryExplorer.Stacktrace)
      assert Enum.all?(stacktraces, &(&1.epoch_id == epoch.id))

      # Check samples have epoch_id
      samples = Repo.all(EctoQueryExplorer.Sample)
      assert Enum.all?(samples, &(&1.epoch_id == epoch.id))

      # Check queries and functions do NOT have epoch_id (content-addressable)
      queries = Repo.all(EctoQueryExplorer.Query)
      assert Enum.all?(queries, &(not Map.has_key?(&1, :epoch_id)))

      functions = Repo.all(EctoQueryExplorer.Function)
      assert Enum.all?(functions, &(not Map.has_key?(&1, :epoch_id)))
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
end

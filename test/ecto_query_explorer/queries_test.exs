defmodule EctoQueryExplorer.QueriesTest do
  use ExUnit.Case, async: false

  alias EctoQueryExplorer.Queries

  defmodule Repo do
    use Ecto.Repo,
      adapter: Ecto.Adapters.SQLite3,
      otp_app: :my_app,
      warn: false
  end

  setup_all do
    Application.put_all_env(
      ecto_query_explorer: [
        ets_table_name: :testing_data_dump,
        repo: Repo
      ]
    )

    setup_app_repo()

    :ok
  end

  setup do
    :ets.new(:testing_data_dump, [:ordered_set, :named_table])

    Application.put_env(:my_app, Repo,
      database: ":memory:",
      pool: Ecto.Adapters.SQL.Sandbox,
      pool_size: 1
    )

    Application.put_env(:ecto_query_explorer, :repo, Repo)

    Repo.__adapter__().storage_up(Repo.config())

    {:ok, _pid} = Repo.start_link()

    :ok = Ecto.Adapters.SQL.Sandbox.mode(Repo, :manual)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    Ecto.Migrator.run(Repo, [{0, EctoQueryExplorer.Migration0}], :up,
      all: true,
      log_migrations_sql: :debug
    )

    :ok
  end

  describe "filter_by_query" do
    test "returns matching query with related data" do
      create_query()

      assert length(Queries.filter_by_query("%select%")) > 0
    end
  end

  describe "filter_by_parameter" do
    test "returns matching query with related data" do
      create_query()

      assert length(Queries.filter_by_parameter(234)) > 0
    end
  end

  describe "filter_by_mfa" do
    test "returns matching query with related data" do
      create_query()

      assert length(Queries.filter_by_mfa(Elixir.App.CodeModule, :init, 1)) > 0
    end
  end

  describe "filter_by_location" do
    test "returns matching query with related data" do
      create_query()

      assert length(Queries.filter_by_location("lib/my_app/path/to/code/module.ex", 12)) > 0
    end
  end

  describe "explain" do
    test "returns json with explain data" do
      create_query()

      assert %{
               "Execution Time" => _,
               "Plan" => %{
                 "Actual Loops" => 1,
                 "Actual Rows" => 0,
                 "Actual Startup Time" => _,
                 "Actual Total Time" => _,
                 "Alias" => "customers",
                 "Async Capable" => false,
                 "Index Cond" => "(customers.id = '234'::bigint)",
                 "Index Name" => "customers_pkey",
                 "Local Dirtied Blocks" => 0,
                 "Local Hit Blocks" => 0,
                 "Local Read Blocks" => 0,
                 "Local Written Blocks" => 0,
                 "Node Type" => "Index Scan",
                 "Output" => ["id", "name"],
                 "Parallel Aware" => false,
                 "Plan Rows" => 1,
                 "Plan Width" => 524,
                 "Relation Name" => "customers",
                 "Rows Removed by Index Recheck" => 0,
                 "Scan Direction" => "Forward",
                 "Schema" => "public",
                 "Shared Dirtied Blocks" => 0,
                 "Shared Hit Blocks" => 2,
                 "Shared Read Blocks" => 0,
                 "Shared Written Blocks" => 0,
                 "Startup Cost" => _,
                 "Temp Read Blocks" => 0,
                 "Temp Written Blocks" => 0,
                 "Total Cost" => _
               },
               "Planning" => %{
                 "Local Dirtied Blocks" => 0,
                 "Local Hit Blocks" => 0,
                 "Local Read Blocks" => 0,
                 "Local Written Blocks" => 0,
                 "Shared Dirtied Blocks" => 0,
                 "Shared Hit Blocks" => _,
                 "Shared Read Blocks" => 1,
                 "Shared Written Blocks" => 0,
                 "Temp Read Blocks" => 0,
                 "Temp Written Blocks" => 0
               },
               "Planning Time" => _,
               "Triggers" => []
             } = Queries.explain(123)
    end
  end

  describe "top_queries" do
    test "returns to N queries" do
      create_query()

      assert length(Queries.top_queries(1)) > 0
    end
  end

  def create_query do
    :ets.insert_new(:testing_data_dump, [
      {{:functions, 10_545_222}, "Elixir.Ecto.Repo.Supervisor", "tuplet", 2},
      {{:functions, 13_607_698}, "gen_server", "init_it", 6},
      {{:functions, 45_708_481}, "Elixir.App.Repo", "all", 2},
      {{:functions, 68_908_858}, "gen_server", "init_it", 2},
      {{:functions, 79_772_134}, "proc_lib", "init_p_do_apply", 3},
      {{:functions, 113_359_675}, "Elixir.App.CodeModule", "init", 1},
      {{:locations, 30_117_895}, "lib/my_app/path/to/code/module.ex", 12},
      {{:locations, 30_369_914}, "lib/my_app/repo.ex", 2},
      {{:locations, 61_301_931}, "proc_lib.erl", 241},
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

    EctoQueryExplorer.Data.dump2sqlite()
  end

  defp setup_app_repo do
    defmodule App.Repo do
      use Ecto.Repo,
        adapter: Ecto.Adapters.Postgres,
        otp_app: :my_app
    end

    Application.put_env(:my_app, App.Repo, database: "app_repo_test", username: "postgres", password: "postgres")

    _ = App.Repo.__adapter__().storage_down(App.Repo.config())
    App.Repo.__adapter__().storage_up(App.Repo.config())

    {:ok, _} = Supervisor.start_link([App.Repo], strategy: :one_for_one)

    defmodule Migration0 do
      use Ecto.Migration

      def change do
        create table("customers") do
          add(:name, :string)
        end
      end
    end

    Ecto.Migrator.run(App.Repo, [{0, Migration0}], :up, all: true, log_migrations_sql: :debug)
  end
end

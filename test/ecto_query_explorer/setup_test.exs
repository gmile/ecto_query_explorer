defmodule EctoQueryExplorer.SetupTest do
  use ExUnit.Case, async: false

  import Ecto.Query

  alias EctoQueryExplorer.{Query, Sample}

  defmodule Repo do
    use Ecto.Repo,
      adapter: Ecto.Adapters.SQLite3,
      otp_app: :my_app,
      warn: false
  end

  setup do
    Application.put_env(:my_app, Repo,
      database: ":memory:",
      pool: Ecto.Adapters.SQL.Sandbox,
      pool_size: 1
    )

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

  describe "attach_handler/1" do
    test "correctly listens for telemetry events of different formats" do
      Application.put_env(:my_app, MyApp.Repo2, telemetry_prefix: [:just_repo2])

      {:ok, _pid} =
        EctoQueryExplorer.start_link(
          repo: Repo,
          otp_app: :my_app,
          source_ecto_repos: [MyApp.Repo1, MyApp.Repo2, MyApp.AnotherRepo, MyApp.Namespace.Repo]
        )

      metadata = %{
        cast_params: nil,
        params: ["background_jobs.oban_insert", []],
        query: "SELECT pg_notify($1, payload) FROM json_array_elements_text($2::json) AS payload",
        repo: MyApp.Repo,
        result: nil,
        source: nil,
        stacktrace: nil,
        type: :ecto_sql_query
      }

      :telemetry.execute([:my_app, :repo1, :query], %{}, metadata)
      :telemetry.execute([:just_repo2, :query], %{}, metadata)
      :telemetry.execute([:my_app, :another_repo, :query], %{}, metadata)
      :telemetry.execute([:my_app, :namespace, :repo, :query], %{}, metadata)

      EctoQueryExplorer.Data.dump2sqlite(:ecto_query_explorer_data, Repo)

      assert 1 == Repo.one(from(q in Query, select: count(q.id)))
      assert 4 == Repo.one(from(s in Sample, select: count(s.id)))
    end
  end
end

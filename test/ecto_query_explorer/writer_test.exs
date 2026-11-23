defmodule EctoQueryExplorer.WriterTest do
  use ExUnit.Case, async: false

  import Ecto.Query

  alias EctoQueryExplorer.{Dump, Query}
  alias EctoQueryExplorer.TestRepo, as: Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok = Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

    Application.put_all_env(
      ecto_query_explorer: [
        otp_app: :my_app,
        ets_table_name: :writer_test_data,
        repo: Repo,
        flush_interval: false,
        source_ecto_repos: [MyApp.Repo]
      ]
    )

    :ok
  end

  defp run_query do
    :telemetry.execute([:my_app, :repo, :query], %{total_time: 100}, %{
      params: [],
      query: "select 1",
      repo: MyApp.Repo,
      source: nil,
      stacktrace: nil
    })
  end

  defp counters do
    Repo.all(from(q in Query, select: q.counter))
  end

  defp wait_for_counters(expected) do
    unless counters() == expected do
      Process.sleep(10)
      wait_for_counters(expected)
    end
  end

  test "flushes on a timer" do
    Application.put_env(:ecto_query_explorer, :flush_interval, 10)
    start_supervised!(EctoQueryExplorer)

    run_query()
    wait_for_counters([1])

    run_query()
    run_query()
    wait_for_counters([3])
  end

  test "flushes on shutdown" do
    start_supervised!(EctoQueryExplorer)

    run_query()
    assert [] == counters()

    stop_supervised!(EctoQueryExplorer)
    assert [1] == counters()
  end

  test "names the dump after the node unless told otherwise" do
    start_supervised!(EctoQueryExplorer)

    run_query()
    assert :ok == EctoQueryExplorer.Data.dump2sqlite()

    run_query()
    assert :ok == EctoQueryExplorer.Data.dump2sqlite(name: "custom")

    assert ["nonode@nohost", "custom"] == Repo.all(from(d in Dump, select: d.name, order_by: d.id))
  end

  @tag :capture_log
  test "reports a flush that could not be written" do
    start_supervised!(EctoQueryExplorer)
    Application.put_env(:ecto_query_explorer, :repo, MissingRepo)

    run_query()

    assert {:error, reason} = EctoQueryExplorer.Data.dump2sqlite()
    assert reason =~ "MissingRepo"
  end
end

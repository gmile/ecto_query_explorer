defmodule EctoQueryExplorer.Cluster do
  alias EctoQueryExplorer.TestRepo

  def start_peer(database) do
    {:ok, peer, node} =
      :peer.start_link(%{
        name: :peer.random_name(),
        host: ~c"127.0.0.1",
        longnames: true,
        connection: :standard_io,
        args: [~c"-setcookie", ~c"ecto_query_explorer" | Enum.flat_map(:code.get_path(), &[~c"-pa", &1])]
      })

    {:ok, _apps} = :peer.call(peer, :application, :ensure_all_started, [:elixir])
    :ok = :peer.call(peer, __MODULE__, :boot, [database])

    {peer, node}
  end

  def boot(database) do
    {:ok, _apps} = Application.ensure_all_started(:ecto_sqlite3)
    Logger.configure(level: :warning)

    Application.put_env(:ecto_query_explorer, TestRepo, database: database, pool_size: 1)

    Application.put_all_env(
      ecto_query_explorer: [
        otp_app: :my_app,
        ets_table_name: :cluster_data,
        repo: TestRepo,
        flush_interval: false,
        samples_to_keep: 2,
        source_ecto_repos: [MyApp.Repo]
      ]
    )

    {:ok, pid} = Supervisor.start_link([TestRepo, EctoQueryExplorer], strategy: :one_for_one, name: __MODULE__)
    Process.unlink(pid)

    :ok
  end

  def migrate do
    Ecto.Migrator.run(TestRepo, [{0, EctoQueryExplorer.Migration0}, {1, EctoQueryExplorer.Migration1}], :up, all: true)
  end
end

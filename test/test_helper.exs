Code.require_file("support/test_repo.ex", __DIR__)

Application.put_env(:ecto_query_explorer, EctoQueryExplorer.TestRepo,
  database: "file::memory:?cache=shared",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 2
)

{:ok, _} = EctoQueryExplorer.TestRepo.start_link()

Ecto.Migrator.run(
  EctoQueryExplorer.TestRepo,
  [{0, EctoQueryExplorer.Migration0}, {1, EctoQueryExplorer.Migration1}],
  :up,
  all: true
)

Ecto.Adapters.SQL.Sandbox.mode(EctoQueryExplorer.TestRepo, :manual)

ExUnit.start()

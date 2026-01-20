# EctoQueryExplorer

[![CI](https://github.com/gmile/ecto_query_explorer/actions/workflows/ci.yml/badge.svg)](https://github.com/gmile/ecto_query_explorer/actions/workflows/ci.yml)

Collect and analyze Ecto query telemetry. Find which code produces which queries, how often, and how long they take.

> [!WARNING]
> Experimental. Use at your own risk.

## Installation

1. Add dependency:

    ```elixir
    {:ecto_query_explorer, "~> 0.1"}
    ```

2. Add a SQLite repo:

    ```elixir
    defmodule MyApp.EctoQueryExplorerRepo do
      use Ecto.Repo, otp_app: :my_app, adapter: Ecto.Adapters.SQLite3
    end
    ```

3. Configure:

    ```elixir
    # Enable stacktraces on your repo
    config :my_app, MyApp.Repo, stacktrace: true

    # Configure the SQLite repo
    config :my_app, MyApp.EctoQueryExplorerRepo,
      database: "/tmp/ecto-query-explorer.sqlite3"

    # Configure EctoQueryExplorer
    config :ecto_query_explorer,
      otp_app: :my_app,
      repo: MyApp.EctoQueryExplorerRepo,
      ets_table_name: :ecto_query_explorer_data,
      samples_to_keep: 5,
      source_ecto_repos: [MyApp.Repo]
    ```

4. Add to supervision tree:

    ```elixir
    children = [
      EctoQueryExplorer,
      MyApp.EctoQueryExplorerRepo
    ]
    ```

5. Run migrations:

    ```elixir
    # In a migration file
    def up, do: EctoQueryExplorer.Migration0.up()
    def down, do: EctoQueryExplorer.Migration0.down()
    ```

## Usage

```elixir
# Dump collected data to SQLite
EctoQueryExplorer.Data.dump2sqlite()

# Find queries by pattern
EctoQueryExplorer.Queries.filter_by_query("SELECT%users%")

# Find queries by origin
EctoQueryExplorer.Queries.filter_by_mfa(MyApp.Accounts, :get_user, 1)

# Get top queries by execution count
EctoQueryExplorer.Queries.top_queries(10)
```

See module docs for more: `EctoQueryExplorer`, `EctoQueryExplorer.Queries`, `EctoQueryExplorer.Data`.

## Releasing

```sh
mix bump patch  # or minor, or major
git push origin main --tags
```

## License

MIT. See [LICENSE](LICENSE).

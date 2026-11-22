# EctoQueryExplorer

[![CI](https://github.com/gmile/ecto_query_explorer/actions/workflows/ci.yml/badge.svg)](https://github.com/gmile/ecto_query_explorer/actions/workflows/ci.yml)

Collect and analyze Ecto query telemetry. Find which code produces which queries, how often, and how long they take.

> [!WARNING]
> Experimental. Use at your own risk.

## Installation

1. Add dependency:

    ```elixir
    {:ecto_query_explorer, "~> 0.4"}
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

## Development

Enter the shell, then use mix as usual:

```sh
nix develop
mix compile
mix dialyzer
mix docs
```

Format the Nix files:

```sh
nix fmt
```

## Running tests

Run everything CI runs, which is the tests against PostgreSQL from nixpkgs,
the docs and dialyzer:

```sh
nix flake check
```

Or run the tests yourself, against a throwaway PostgreSQL listening on
`PGPORT`, 5432 by default:

```sh
nix run .#postgres &
mix test
```

## Releasing

From a clean `main` that matches `origin/main`, with `major`, `minor` or `patch`:

```sh
nix run .#release -- minor
```

It does what you would by hand:

1. Bump `VERSION` and rename the `[Unreleased]` section of `CHANGELOG.md` to
   `[vX.Y.Z] - YYYY-MM-DD`, with a new empty `[Unreleased]` above it.
2. Commit.
3. Push to `main`.

Once the tests pass, CI publishes the package and its docs to Hex and creates
the GitHub release. A release that failed before its tag was created can be
retried by running the CI workflow on `main`.

## License

MIT. See [LICENSE](LICENSE).

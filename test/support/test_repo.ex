defmodule EctoQueryExplorer.TestRepo do
  use Ecto.Repo,
    adapter: Ecto.Adapters.SQLite3,
    otp_app: :ecto_query_explorer
end

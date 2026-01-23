defmodule EctoQueryExplorer.Dump do
  use Ecto.Schema

  schema "dumps" do
    field :name, :string
    field :collected_at, :utc_datetime_usec
  end
end

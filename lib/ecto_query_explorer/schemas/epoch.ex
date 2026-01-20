defmodule EctoQueryExplorer.Epoch do
  use Ecto.Schema

  schema "epochs" do
    field :name, :string
    field :collected_at, :utc_datetime_usec
  end
end

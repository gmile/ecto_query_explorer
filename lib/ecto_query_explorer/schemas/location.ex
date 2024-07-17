defmodule EctoQueryExplorer.Location do
  use Ecto.Schema

  schema "locations" do
    field :file, :string
    field :line, :integer
  end
end

defmodule EctoQueryExplorer.Location do
  use Ecto.Schema

  alias EctoQueryExplorer.Dump

  schema "locations" do
    field :file, :string
    field :line, :integer

    belongs_to :dump, Dump
  end
end

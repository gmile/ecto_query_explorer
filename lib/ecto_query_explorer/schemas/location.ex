defmodule EctoQueryExplorer.Location do
  use Ecto.Schema

  alias EctoQueryExplorer.Epoch

  schema "locations" do
    field :file, :string
    field :line, :integer

    belongs_to :epoch, Epoch
  end
end

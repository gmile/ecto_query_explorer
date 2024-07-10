defmodule EctoQueryExplorer.Params do
  use Ecto.Schema

  alias EctoQueryExplorer.Sample

  schema "params" do
    field :values, :binary

    belongs_to :sample, Sample
  end
end

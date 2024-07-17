defmodule EctoQueryExplorer.Function do
  use Ecto.Schema

  schema "functions" do
    field :module, :string
    field :function, :string
    field :arity, :integer
  end
end

defmodule EctoQueryExplorer.Query do
  use Ecto.Schema

  alias EctoQueryExplorer.{Sample, StacktraceEntry}

  schema "queries" do
    field :text, :string
    field :repo, :string
    field :source, :string
    field :counter, :integer

    has_many :samples, Sample
  end
end

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

defmodule EctoQueryExplorer.Function do
  use Ecto.Schema

  schema "functions" do
    field :module, :string
    field :function, :string
    field :arity, :integer
    field :counter, :integer
  end
end

defmodule EctoQueryExplorer.Location do
  use Ecto.Schema

  schema "locations" do
    field :file, :string
    field :line, :integer
    field :counter, :integer
  end
end

defmodule EctoQueryExplorer.Stacktrace do
  use Ecto.Schema

  alias EctoQueryExplorer.StacktraceEntry

  schema "stacktraces" do
    field :counter, :integer

    has_many :stacktrace_entries, StacktraceEntry
  end
end

defmodule EctoQueryExplorer.StacktraceEntry do
  use Ecto.Schema

  alias EctoQueryExplorer.{Stacktrace, Function, Location}

  schema "stacktrace_entries" do
    field :index, :integer

    belongs_to :stacktrace, Stacktrace
    belongs_to :function, Function
    belongs_to :location, Location
  end
end

defmodule EctoQueryExplorer.Sample do
  use Ecto.Schema

  alias EctoQueryExplorer.{Query, Stacktrace, Params}

  schema "samples" do
    field :total_time, :integer
    field :decode_time, :integer
    field :query_time, :integer
    field :queue_time, :integer

    has_one :params, Params
    belongs_to :query, Query
    belongs_to :stacktrace, Stacktrace

    timestamps type: :utc_datetime_usec, updated_at: false
  end
end

defmodule EctoQueryExplorer.Params do
  use Ecto.Schema

  alias EctoQueryExplorer.Sample

  schema "params" do
    field :values, :binary

    belongs_to :sample, Sample
  end
end

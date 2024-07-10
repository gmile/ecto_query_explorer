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

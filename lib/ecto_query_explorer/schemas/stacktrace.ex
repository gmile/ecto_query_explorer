defmodule EctoQueryExplorer.Stacktrace do
  use Ecto.Schema

  alias EctoQueryExplorer.StacktraceEntry

  schema "stacktraces" do
    field :counter, :integer

    has_many :stacktrace_entries, StacktraceEntry
  end
end

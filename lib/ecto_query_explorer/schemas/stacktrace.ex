defmodule EctoQueryExplorer.Stacktrace do
  use Ecto.Schema

  alias EctoQueryExplorer.{Dump, StacktraceEntry}

  schema "stacktraces" do
    field :counter, :integer

    belongs_to :dump, Dump
    has_many :stacktrace_entries, StacktraceEntry
  end
end

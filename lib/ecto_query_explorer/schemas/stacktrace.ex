defmodule EctoQueryExplorer.Stacktrace do
  use Ecto.Schema

  alias EctoQueryExplorer.{Epoch, StacktraceEntry}

  schema "stacktraces" do
    field :counter, :integer

    belongs_to :epoch, Epoch
    has_many :stacktrace_entries, StacktraceEntry
  end
end

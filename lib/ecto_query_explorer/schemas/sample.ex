defmodule EctoQueryExplorer.Sample do
  use Ecto.Schema

  alias EctoQueryExplorer.{Epoch, Query, Stacktrace}

  schema "samples" do
    field :total_time, :integer
    field :decode_time, :integer
    field :query_time, :integer
    field :queue_time, :integer
    field :params, :binary

    belongs_to :epoch, Epoch
    belongs_to :query, Query
    belongs_to :stacktrace, Stacktrace

    timestamps type: :utc_datetime_usec, updated_at: false
  end
end

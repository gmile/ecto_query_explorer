defmodule EctoQueryExplorer.Migration1 do
  @moduledoc """
  Adds epochs support for tracking data provenance across deployments.

  Epochs allow you to:
  - Track which deployment/code version produced each piece of data
  - Properly merge data from multiple pods without losing context
  - Understand how query patterns change across releases
  """

  use Ecto.Migration

  def up do
    create_if_not_exists table("epochs") do
      add(:name, :string)
      add(:collected_at, :utc_datetime_usec, null: false)
    end

    # Add epoch_id to tables where it matters for provenance
    alter table("locations") do
      add_if_not_exists(:epoch_id, references("epochs"))
    end

    alter table("stacktraces") do
      add_if_not_exists(:epoch_id, references("epochs"))
    end

    alter table("samples") do
      add_if_not_exists(:epoch_id, references("epochs"))
    end

    # Indexes for efficient epoch-based queries
    create_if_not_exists(index("locations", [:epoch_id]))
    create_if_not_exists(index("stacktraces", [:epoch_id]))
    create_if_not_exists(index("samples", [:epoch_id]))

    # Update unique index on locations to include epoch_id
    # Same file:line in different epochs should be different records
    drop_if_exists(index("locations", [:file, :line]))
    create_if_not_exists(index("locations", [:file, :line, :epoch_id], unique: true))

    # Update unique index on stacktrace_entries to account for epoch
    # (stacktrace_id already carries epoch context via its epoch_id)
  end

  def down do
    # Restore original unique index
    drop_if_exists(index("locations", [:file, :line, :epoch_id]))
    create_if_not_exists(index("locations", [:file, :line], unique: true))

    # Remove epoch indexes
    drop_if_exists(index("samples", [:epoch_id]))
    drop_if_exists(index("stacktraces", [:epoch_id]))
    drop_if_exists(index("locations", [:epoch_id]))

    # Remove epoch_id columns
    alter table("samples") do
      remove_if_exists(:epoch_id, :integer)
    end

    alter table("stacktraces") do
      remove_if_exists(:epoch_id, :integer)
    end

    alter table("locations") do
      remove_if_exists(:epoch_id, :integer)
    end

    drop_if_exists(table("epochs"))
  end
end

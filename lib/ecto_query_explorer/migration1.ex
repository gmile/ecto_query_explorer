defmodule EctoQueryExplorer.Migration1 do
  @moduledoc """
  Adds dumps support for tracking data provenance across deployments.

  Dumps allow you to:
  - Track which deployment/code version produced each piece of data
  - Properly merge data from multiple pods without losing context
  - Understand how query patterns change across releases
  """

  use Ecto.Migration

  def up do
    create_if_not_exists table("dumps") do
      add(:name, :string)
      add(:collected_at, :utc_datetime_usec, null: false)
    end

    create_if_not_exists(index("dumps", [:name], unique: true))

    # Add dump_id to tables where it matters for provenance
    # Note: SQLite doesn't support ALTER TABLE ADD COLUMN with REFERENCES,
    # so we add the column without the constraint. The relationship is
    # enforced at the application level via Ecto schemas.
    execute("ALTER TABLE locations ADD COLUMN dump_id INTEGER")
    execute("ALTER TABLE stacktraces ADD COLUMN dump_id INTEGER")
    execute("ALTER TABLE samples ADD COLUMN dump_id INTEGER")

    # Indexes for efficient epoch-based queries
    create_if_not_exists(index("locations", [:dump_id]))
    create_if_not_exists(index("stacktraces", [:dump_id]))
    create_if_not_exists(index("samples", [:dump_id]))

    # Update unique index on locations to include dump_id
    # Same file:line in different dumps should be different records
    drop_if_exists(index("locations", [:file, :line]))
    create_if_not_exists(index("locations", [:file, :line, :dump_id], unique: true))
  end

  def down do
    # Restore original unique index
    drop_if_exists(index("locations", [:file, :line, :dump_id]))
    create_if_not_exists(index("locations", [:file, :line], unique: true))

    # Remove epoch indexes
    drop_if_exists(index("samples", [:dump_id]))
    drop_if_exists(index("stacktraces", [:dump_id]))
    drop_if_exists(index("locations", [:dump_id]))

    # Remove dump_id columns
    alter table("samples") do
      remove_if_exists(:dump_id, :integer)
    end

    alter table("stacktraces") do
      remove_if_exists(:dump_id, :integer)
    end

    alter table("locations") do
      remove_if_exists(:dump_id, :integer)
    end

    drop_if_exists(index("dumps", [:name]))
    drop_if_exists(table("dumps"))
  end
end

defmodule EctoQueryExplorer.Migration0 do
  @moduledoc false

  use Ecto.Migration

  def up do
    create_if_not_exists table("queries") do
      add(:text, :text, null: false)
      add(:repo, :string, null: false)
      add(:source, :string)
      add(:counter, :integer, null: false)
    end

    create_if_not_exists table("functions") do
      add(:module, :string, null: false)
      add(:function, :string, null: false)
      add(:arity, :integer, null: false)
      add(:counter, :integer, null: false)
    end

    create_if_not_exists table("locations") do
      add(:file, :string, null: false)
      add(:line, :integer, null: false)
      add(:counter, :integer, null: false)
    end

    create_if_not_exists table("stacktraces") do
      add(:counter, :integer, null: false)
    end

    create_if_not_exists table("stacktrace_entries") do
      add(:index, :integer, null: false)
      add(:stacktrace_id, references("stacktraces"), null: false)
      add(:function_id, references("functions"), null: false)
      add(:location_id, references("locations"))
    end

    create_if_not_exists table("samples") do
      add(:query_id, references("queries"), null: false)
      add(:stacktrace_id, references("stacktraces"), null: false)
      add(:total_time, :integer)
      add(:decode_time, :integer)
      add(:query_time, :integer)
      add(:queue_time, :integer)

      timestamps(
        type: :utc_datetime_usec,
        null: false,
        updated_at: false,
        default: fragment("CURRENT_TIMESTAMP")
      )
    end

    create_if_not_exists table("params") do
      add(:sample_id, references("samples"), null: false)
      add(:values, :binary, null: false)

      timestamps(
        inserted_at: false,
        updated_at: false
      )
    end

    create_if_not_exists(index("queries", [:repo, :text], unique: true))
    create_if_not_exists(index("samples", [:query_id, :stacktrace_id]))
    create_if_not_exists(index("functions", [:module, :function, :arity], unique: true))
    create_if_not_exists(index("locations", [:file, :line], unique: true))
    create_if_not_exists(index("params", [:sample_id], unique: true))

    create_if_not_exists(
      index("stacktrace_entries", [:stacktrace_id, :function_id, :location_id, :index],
        unique: true
      )
    )
  end

  def down do
    drop_if_exists(table("queries"))
    drop_if_exists(table("samples"))
    drop_if_exists(table("functions"))
    drop_if_exists(table("locations"))
    drop_if_exists(table("stacktrace_entries"))
    drop_if_exists(table("params"))
  end
end

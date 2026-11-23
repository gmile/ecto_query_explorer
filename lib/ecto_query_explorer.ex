defmodule EctoQueryExplorer do
  @moduledoc """
  Collects and analyzes Ecto query telemetry data.

  EctoQueryExplorer hooks into Ecto's telemetry events to capture query execution data,
  including stacktraces that show where each query originated. Data is stored in ETS
  during runtime and can be dumped to SQLite for analysis.

  ## How it works

  1. Attaches to `[:my_app, :repo, :query]` telemetry events
  2. Captures query text, timing, parameters, and stacktraces in ETS
  3. On demand, dumps ETS data to SQLite via `EctoQueryExplorer.Data.dump2sqlite/1`
  4. Query the SQLite database using `EctoQueryExplorer.Queries` functions

  ## Configuration

      config :ecto_query_explorer,
        otp_app: :my_app,
        repo: MyApp.EctoQueryExplorerRepo,
        ets_table_name: :ecto_query_explorer_data,
        samples_to_keep: 5,
        source_ecto_repos: [MyApp.Repo]

  ## Database schema

  The SQLite database contains these tables:

  - `queries` - unique query texts with execution counts
  - `samples` - individual query executions with timing data
  - `stacktraces` - unique call stacks
  - `stacktrace_entries` - individual stack frames
  - `functions` - unique module/function/arity combinations
  - `locations` - unique file/line combinations
  - `dumps` - data provenance tracking for multi-pod environments

  See the schema diagram in the repository for relationships.
  """

  use GenServer

  # Client

  def child_spec(_options) do
    children = [%{id: __MODULE__, start: {__MODULE__, :start_link, []}}, EctoQueryExplorer.Writer]

    %{id: __MODULE__, type: :supervisor, start: {Supervisor, :start_link, [children, [strategy: :one_for_one]]}}
  end

  def start_link(_options \\ []) do
    options =
      Application.get_all_env(:ecto_query_explorer)
      |> Keyword.put_new(:last_sample_id, 0)

    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  def handle_event(event, measurements, metadata, config) do
    GenServer.cast(__MODULE__, {:handle_event, event, measurements, metadata, config})
  end

  def drain do
    GenServer.call(__MODULE__, :drain)
  end

  # Server

  @impl true
  def init(state) do
    :ets.new(state[:ets_table_name], [:ordered_set, :named_table])

    events =
      Enum.map(
        state[:source_ecto_repos],
        &(telemetry_prefix(state[:otp_app], &1) ++ [:query])
      )

    config = [
      repo: state[:repo],
      ets_table_name: state[:ets_table_name],
      samples_to_keep: state[:samples_to_keep]
    ]

    :telemetry.detach(__MODULE__)

    case :telemetry.attach_many(__MODULE__, events, &EctoQueryExplorer.handle_event/4, config) do
      :ok ->
        {:ok, state}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_cast({:handle_event, event, measurements, metadata, config}, state) do
    sample_id = state[:last_sample_id] + 1

    EctoQueryExplorer.Handler.handle_event(event, measurements, metadata, config, %{
      sample_id: sample_id
    })

    {:noreply, Keyword.update!(state, :last_sample_id, fn _existing_value -> sample_id end)}
  end

  @impl true
  def handle_call(:drain, _from, state) do
    table = state[:ets_table_name]
    rows = table |> :ets.tab2list() |> Enum.filter(&(tuple_size(elem(&1, 0)) == 2))
    :ets.delete_all_objects(table)

    {:reply, rows, state}
  end

  defp telemetry_prefix(otp_app, repo) do
    case otp_app
         |> Application.get_env(repo, [])
         |> Keyword.get(:telemetry_prefix) do
      prefix when is_list(prefix) ->
        prefix

      _ ->
        repo
        |> Module.split()
        |> Enum.map(&(&1 |> Macro.underscore() |> String.to_atom()))
    end
  end
end

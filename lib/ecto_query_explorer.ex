defmodule EctoQueryExplorer do
  use GenServer

  # Client

  def start_link(_options \\ []) do
    options =
      Application.get_all_env(:ecto_query_explorer)
      |> Keyword.put_new(:last_sample_id, 0)

    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  def handle_event(event, measurements, metadata, config) do
    GenServer.cast(__MODULE__, {:handle_event, event, measurements, metadata, config})
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
      samples_to_keep: 5
    ]

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

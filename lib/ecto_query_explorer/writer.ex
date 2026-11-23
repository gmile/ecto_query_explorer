defmodule EctoQueryExplorer.Writer do
  @moduledoc false

  use GenServer

  require Logger

  @call_timeout :timer.seconds(60)

  def start_link(_options) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def flush(options \\ []) do
    GenServer.call(__MODULE__, {:flush, options}, @call_timeout)
  end

  @impl true
  def init(_options) do
    Process.flag(:trap_exit, true)

    {:ok, schedule(%{interval: Application.get_env(:ecto_query_explorer, :flush_interval, :timer.seconds(60))})}
  end

  @impl true
  def handle_call({:flush, options}, _from, state) do
    {:reply, flush_collected(options), state}
  end

  @impl true
  def handle_info(:flush, state) do
    flush_collected([])

    {:noreply, schedule(state)}
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, _state) do
    flush_collected([])
  end

  defp schedule(%{interval: interval} = state) when is_integer(interval) do
    Process.send_after(self(), :flush, interval)

    state
  end

  defp schedule(state), do: state

  defp flush_collected(options) do
    with [_ | _] = rows <- EctoQueryExplorer.drain(),
         {:error, reason} = error <- merge(rows, options[:name] || to_string(node())) do
      Logger.warning("EctoQueryExplorer dropped collected data: #{inspect(reason)}")

      error
    else
      _ -> :ok
    end
  end

  defp merge(rows, dump_name) do
    EctoQueryExplorer.Data.merge(rows, dump_name)
  catch
    kind, reason -> {:error, Exception.format_banner(kind, reason, __STACKTRACE__)}
  end
end

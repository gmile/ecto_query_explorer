defmodule EctoQueryExplorer.Writer do
  @moduledoc false

  use GenServer

  require Logger

  @call_timeout :timer.seconds(60)

  def start_link(_options) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def flush(options \\ []) do
    {replies, _unreachable} =
      GenServer.multi_call([node() | Node.list()], __MODULE__, {:flush, options}, @call_timeout)

    case for {node, {:error, reason}} <- replies, do: {node, reason} do
      [] -> :ok
      failures -> {:error, failures}
    end
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

  def handle_call({:merge, rows, dump_name}, _from, state) do
    {:reply, merge(rows, dump_name), state}
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
    with leader when is_pid(leader) <- leader(),
         [_ | _] = rows <- EctoQueryExplorer.drain(),
         {:error, reason} = error <- deliver(leader, rows, options[:name] || to_string(node())) do
      Logger.warning("EctoQueryExplorer dropped collected data: #{inspect(reason)}")

      error
    else
      :undefined -> {:error, :no_leader}
      _ -> :ok
    end
  end

  defp name, do: {__MODULE__, Application.fetch_env!(:ecto_query_explorer, :otp_app)}

  defp leader do
    with :undefined <- :global.whereis_name(name()),
         :yes <- :global.register_name(name(), self(), &:global.notify_all_name/3) do
      self()
    else
      :no -> :global.whereis_name(name())
      pid -> pid
    end
  end

  defp deliver(leader, rows, dump_name) when leader == self(), do: merge(rows, dump_name)

  defp deliver(leader, rows, dump_name) do
    GenServer.call(leader, {:merge, rows, dump_name}, @call_timeout)
  catch
    :exit, reason -> {:error, reason}
  end

  defp merge(rows, dump_name) do
    if :global.whereis_name(name()) == self() do
      EctoQueryExplorer.Data.merge(rows, dump_name)
    else
      {:error, :not_leader}
    end
  catch
    kind, reason -> {:error, Exception.format_banner(kind, reason, __STACKTRACE__)}
  end
end

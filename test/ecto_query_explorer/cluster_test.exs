defmodule EctoQueryExplorer.ClusterTest do
  use ExUnit.Case, async: false

  alias EctoQueryExplorer.{Cluster, TestRepo, Writer}

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    database = Path.join(tmp_dir, "cluster.sqlite3")

    [{first, _node} | _] = peers = for _ <- 1..3, do: Cluster.start_peer(database)

    :peer.call(first, Cluster, :migrate, [])

    for {peer, _node} <- peers, {_peer, node} <- peers do
      :peer.call(peer, :net_kernel, :connect_node, [node])
    end

    for {peer, _node} <- peers, do: :peer.call(peer, :global, :sync, [])

    %{peers: peers}
  end

  defp run_query(peer, total_time) do
    :peer.call(peer, :telemetry, :execute, [
      [:my_app, :repo, :query],
      %{total_time: total_time},
      %{params: [], query: "select 1", repo: MyApp.Repo, source: nil, stacktrace: nil}
    ])
  end

  defp dump(peer), do: :ok = :peer.call(peer, EctoQueryExplorer.Data, :dump2sqlite, [])

  defp rows(peer, sql), do: :peer.call(peer, TestRepo, :query!, [sql]).rows

  defp leader(peer), do: :peer.call(peer, :global, :whereis_name, [{Writer, :my_app}])

  defp wait_until(fun) do
    unless fun.() do
      Process.sleep(50)
      wait_until(fun)
    end
  end

  test "one node writes what every node collected", %{peers: [{first, _} | _] = peers} do
    for {{peer, _node}, index} <- Enum.with_index(peers), total_time <- [index * 10 + 1, index * 10 + 2] do
      run_query(peer, total_time)
    end

    dump(first)

    assert [[6]] == rows(first, "select counter from queries")
    assert [[22], [21]] == rows(first, "select total_time from samples order by total_time desc")

    assert Enum.sort(for {_peer, node} <- peers, do: [to_string(node)]) ==
             rows(first, "select name from dumps order by name")

    assert [pid] = Enum.uniq(for {peer, _node} <- peers, do: leader(peer))
    assert is_pid(pid)
  end

  test "another node takes over when the leader stops", %{peers: [{first, _} | _] = peers} do
    run_query(first, 1)
    dump(first)

    old_leader = leader(first)
    {[{leader_peer, _}], [{survivor, _} | _] = survivors} = Enum.split_with(peers, &(elem(&1, 1) == node(old_leader)))

    :peer.stop(leader_peer)
    wait_until(fn -> Enum.all?(survivors, &(leader(elem(&1, 0)) != old_leader)) end)

    for {peer, _node} <- survivors, do: run_query(peer, 1)
    dump(survivor)

    assert [[3]] == rows(survivor, "select counter from queries")
    assert node(leader(survivor)) in for({_peer, node} <- survivors, do: node)
  end

  test "a stopping node hands its data to the leader", %{peers: [{first, _} | _] = peers} do
    dump(first)

    leader_node = node(leader(first))
    {[{leader_peer, _}], [{follower, _} | _]} = Enum.split_with(peers, &(elem(&1, 1) == leader_node))

    run_query(follower, 1)
    :peer.call(follower, Supervisor, :stop, [Cluster])

    assert [[1]] == rows(leader_peer, "select counter from queries")
  end
end

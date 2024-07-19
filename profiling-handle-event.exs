if :ets.whereis(:ecto_query_explorer_data) == :undefined do
  :ets.new(:ecto_query_explorer_data, [:ordered_set, :named_table])
end

metadata1 = %{
  params: [1, 2],
  query: "select $1, $2",
  repo: App.Repo,
  source: nil,
  stacktrace: [
    {Module1, :fun1, 1, [file: ~c"lib/path/to/file1.ex", line: 10]},
    {Module2, :fun2, 2, [file: ~c"lib/path/to/file2.ex", line: 20]},
    {Module3, :fun3, 3, [file: ~c"lib/path/to/file3.ex", line: 30]}
  ]
}

metadata2 = %{
  params: [1, 2],
  query: "select $1, $2",
  repo: App.Repo,
  source: nil,
  stacktrace: [
    {Module1, :fun1, 1, [file: ~c"lib/path/to/file1.ex", line: 10]},
    {Module2, :fun2, 2, [file: ~c"lib/path/to/file2.ex", line: 20]},
    {Module4, :fun4, 4, [file: ~c"lib/path/to/file4.ex", line: 40]}
  ]
}

metadata3 = %{
  params: [1, 2],
  query: "select $1, $2, $3",
  repo: App.Repo,
  source: nil,
  stacktrace: [
    {Module1, :fun1, 1, [file: ~c"lib/path/to/file1.ex", line: 10]},
    {Module2, :fun2, 2, [file: ~c"lib/path/to/file2.ex", line: 20]},
    {Module4, :fun4, 4, [file: ~c"lib/path/to/file4.ex", line: 40]}
  ]
}

for i <- 1..1000 do
  EctoQueryExplorer.Handler.handle_event(
    "any-name",
    %{total_time: 8},
    metadata1,
    [repo: Repo, ets_table_name: :ecto_query_explorer_data, samples_to_keep: 3],
    %{sample_id: i + 1}
  )

  EctoQueryExplorer.Handler.handle_event(
    "any-name",
    %{total_time: 9},
    metadata2,
    [repo: Repo, ets_table_name: :ecto_query_explorer_data, samples_to_keep: 3],
    %{sample_id: i + 2}
  )

  EctoQueryExplorer.Handler.handle_event(
    "any-name",
    %{total_time: 10},
    metadata3,
    [repo: Repo, ets_table_name: :ecto_query_explorer_data, samples_to_keep: 3],
    %{sample_id: i + 3}
  )

  EctoQueryExplorer.Handler.handle_event(
    "any-name",
    %{total_time: 11},
    metadata3,
    [repo: Repo, ets_table_name: :ecto_query_explorer_data, samples_to_keep: 3],
    %{sample_id: i + 4}
  )
end

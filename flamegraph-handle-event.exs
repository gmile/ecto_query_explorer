module = EctoQueryExplorer.Handler
fun = :handle_event
args = [
  "any-name",
  %{total_time: 8},
  %{
    params: [1, 2],
    query: "select $1, $2",
    repo: App.Repo,
    source: nil,
    stacktrace: [
      {Module1, :fun1, 1, [file: ~c"lib/path/to/file1.ex", line: 10]},
      {Module2, :fun2, 2, [file: ~c"lib/path/to/file2.ex", line: 20]},
      {Module3, :fun3, 3, [file: ~c"lib/path/to/file3.ex", line: 30]}
    ]
  },
  [repo: Repo, ets_table_name: :ecto_query_explorer_data, samples_to_keep: 3],
  %{sample_id: 1}
]

:ets.new(:ecto_query_explorer_data, [:ordered_set, :named_table])

:eflambe.apply({module, fun, args}, output_format: :brendan_gregg)

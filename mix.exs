defmodule EctoQueryExplorer.MixProject do
  use Mix.Project

  @version File.read!("VERSION") |> String.trim()
  @source_url "https://github.com/gmile/ecto_query_explorer"

  def project do
    [
      app: :ecto_query_explorer,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      name: "EctoQueryExplorer",
      description: "Collect and analyze Ecto query telemetry",
      source_url: @source_url
    ]
  end

  defp deps do
    [
      {:telemetry, "~> 1.3"},
      {:ecto_sqlite3, "~> 0.22"},
      {:ex_doc, "~> 0.39", only: :dev, runtime: false},
      {:eflambe, "~> 0.3", only: :dev},
      {:postgrex, "~> 0.22", only: [:dev, :test]},
      {:jason, "~> 1.4", only: [:dev, :test]}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"]
    ]
  end

  defp package do
    [
      maintainers: ["Ievgen Pyrogov"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib .formatter.exs mix.exs VERSION README.md LICENSE CHANGELOG.md)
    ]
  end
end

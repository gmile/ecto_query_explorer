defmodule EctoQueryExplorer.MixProject do
  use Mix.Project

  def project do
    [
      app: :ecto_query_explorer,
      version: "0.1.1",
      elixir: "~> 1.17",
      package: package(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:elixir_make, "~> 0.8"},
      {:telemetry, "~> 1.0"},
      {:ecto_sqlite3, "~> 0.16"},
      {:postgrex, "~> 0.15", only: ~w(dev test)a},
      {:jason, "~> 1.0", only: ~w(dev test)a}
    ]
  end

  def package do
    [
      name: :ecto_query_explorer,
      description: "A tool used to gather and analyse Ecto query telemetry",
      maintainers: ["Ievgen Pyrogov"],
      licenses: ["MIT"],
      files: ["lib/*", "mix.exs", "README.md", "LICENSE", "CHANGELOG.md"],
      links: %{
        "GitHub" => "https://github.com/gmile/ecto_query_explorer"
      }
    ]
  end
end

defmodule EctoDBScanner.MixProject do
  use Mix.Project

  @version "0.3.0"
  @source_url "https://github.com/mylanconnolly/ecto-db-scanner"

  def project do
    [
      app: :ecto_db_scanner,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      name: "EctoDBScanner",
      description:
        "A PostgreSQL database scanner that discovers structure, maps types, and detects enums.",
      source_url: @source_url,
      homepage_url: @source_url,
      package: package(),
      docs: docs()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.12"},
      {:postgrex, "~> 0.20"},
      {:reactor, "~> 1.0"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "EctoDBScanner",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"]
    ]
  end
end

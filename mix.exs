defmodule ContextKit.MixProject do
  use Mix.Project

  @version "0.2.0"
  @source_url "https://github.com/egze/context_kit"

  def project do
    [
      app: :context_kit,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      name: "ContextKit",
      docs: docs(),
      description:
        "ContextKit is a modular toolkit for building robust Phoenix/Ecto contexts with standardized CRUD operations",
      source_url: @source_url
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp docs do
    [
      main: "ContextKit",
      source_ref: "v#{@version}",
      source_url: @source_url,
      nest_modules_by_prefix: [ContextKit]
    ]
  end

  defp package do
    [
      maintainers: ["Aleksandr Lossenko"],
      licenses: ["MIT"],
      links: %{github: @source_url},
      files: ~w(lib CHANGELOG.md LICENSE.md mix.exs README.md)
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, "~> 3.8"},
      {:ecto_sql, "~> 3.12"},
      {:ecto_sqlite3, ">= 0.0.0", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:phoenix, ">= 1.7.0"},
      {:styler, "~> 1.0", only: [:dev, :test], runtime: false}
    ]
  end
end

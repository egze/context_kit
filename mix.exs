defmodule ContextKit.MixProject do
  use Mix.Project

  def project do
    [
      app: :context_kit,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:inflex, "~> 2.1"},
      {:ecto, "~> 3.12"}
    ]
  end
end

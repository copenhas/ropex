defmodule Rope.Mixfile do
  use Mix.Project

  def project do
    [
      app: :rope,
      version: "0.1.2",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps(),

      # Docs
      name: "ropex",
      source_url: "https://github.com/ijcd/ropex",
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
      {:apex, "~>1.0.0"},
      {:mix_test_watch, "~> 0.3", only: :dev, runtime: false},
      {:credo, "~> 0.8.5"},
      {:dialyxir, "~> 0.5", only: [:dev, :test], runtime: false},
      # {:stream_data, "~> 0.2.0"},
    ]
  end
end

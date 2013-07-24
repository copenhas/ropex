defmodule Rope.Mixfile do
  use Mix.Project

  def project do
    [ app: :rope,
      version: "0.0.1",
      elixir: "~> 0.10.0",
      name: "ropex",
      source_url: "https://github.com/copenhas/ropex",
      deps: deps ]
  end

  # Configuration for the OTP application
  def application do
    []
  end

  # Returns the list of dependencies in the format:
  # { :foobar, "0.1", git: "https://github.com/elixir-lang/foobar.git" }
  defp deps do
    [
      { :ex_doc, github: "elixir-lang/ex_doc" }
    ]
  end
end

defmodule Rope.Mixfile do
  use Mix.Project

  def version do
    "v0.1.1"
  end

  def source_url do
    "https://github.com/copenhas/ropex"
  end

  def project do
    [ app: :rope,
      version: version,
      elixir: "~> 0.10.0",
      name: "ropex",
      source_url: source_url,
      deps: deps,
      docs: [
        source_url_pattern: "#{source_url}/blob/#{version}/%{path}#L%{line}"
      ]
    ]
  end

  # Configuration for the OTP application
  def application do
    [
    ]
  end

  # Returns the list of dependencies in the format:
  # { :foobar, "0.1", git: "https://github.com/elixir-lang/foobar.git" }
  defp deps do
    [
      { :ex_doc, github: "elixir-lang/ex_doc" }
    ]
  end
end

defmodule Delux.MixProject do
  use Mix.Project

  @version "0.4.1"
  @source_url "https://github.com/smartrent/delux"

  def project do
    [
      app: :delux,
      version: @version,
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      docs: docs(),
      dialyzer: dialyzer(),
      deps: deps()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger],
      mod: {Delux.Application, []}
    ]
  end

  def cli do
    [
      preferred_envs: %{
        dialyzer: :test,
        docs: :docs,
        "hex.build": :docs,
        "hex.publish": :docs,
        credo: :test
      }
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.22", only: :docs, runtime: false},
      {:dialyxir, "~> 1.1", only: :test, runtime: false},
      {:credo, "~> 1.5", only: :test, runtime: false}
    ]
  end

  defp docs do
    [
      extras: ["README.md", "CHANGELOG.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end

  defp description do
    "Use LEDs for your user interface"
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{"Github" => @source_url}
    ]
  end

  defp dialyzer() do
    [
      flags: [:missing_return, :extra_return, :unmatched_returns, :error_handling, :underspecs]
    ]
  end
end

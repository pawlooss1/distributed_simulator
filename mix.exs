defmodule DistributedSimulator.MixProject do
  use Mix.Project

  def project do
    [
      app: :distributed_simulator,
      version: "0.1.0",
      elixir: "~> 1.11",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp docs do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end

  defp deps do
    if System.user_home() == "/Users/samuelheldak" do
      [
        {:nx, path: "/Users/samuelheldak/studies/nx/nx", override: true},
        {:exla, path: "/Users/samuelheldak/studies/nx/exla", override: true},
        {:ex_doc, "~> 0.24", only: :dev}
      ]
    else
      [
        {:nx, path: "/Users/agnieszkadutka/repos/inz/nx/nx", override: true},
        {:exla, path: "/Users/agnieszkadutka/repos/inz/nx/exla", override: true},
        {:ex_doc, "~> 0.24", only: :dev,}
      ]
    end
  end
end

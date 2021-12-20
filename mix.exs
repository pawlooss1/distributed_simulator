defmodule DistributedSimulator.MixProject do
  use Mix.Project

  def project do
    [
      app: :distributed_simulator,
      version: "0.1.0",
      elixir: "~> 1.11",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    if System.user_home() == "/Users/samuelheldak" do
      [
        {:nx, path: "/Users/samuelheldak/studies/nx/nx", override: true},
        {:exla, path: "/Users/samuelheldak/studies/nx/exla", override: true}
      ]
    else
      [
        {:nx, path: "/Users/agnieszkadutka/repos/inz/nx/nx", override: true},
        {:exla, path: "/Users/agnieszkadutka/repos/inz/nx/exla", override: true}
      ]
    end
  end
end

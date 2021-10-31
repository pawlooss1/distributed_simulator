defmodule DistributedSimulator.MixProject do
  use Mix.Project

  def project do
    [
      app: :distributed_simulator,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # {:exla, "~> 0.1.0-dev", github: "elixir-nx/nx", sparse: "exla"},
      # {:nx, path: "/home/sheldak/thesis/nx/nx", override: true}
      # {:nx, path: "/Users/samuelheldak/studies/nx/nx", override: true}
      {:nx, path: "/Users/agnieszkadutka/repos/inz/nx/nx", override: true}
      # {:nx, "~> 0.1.0-dev", github: "elixir-nx/nx", branch: "main", sparse: "nx", override: true}
    ]
  end
end

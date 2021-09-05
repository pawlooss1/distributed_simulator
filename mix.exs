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

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:typed_struct, "~> 0.2.1"},
#      {:exla, "~> 0.1.0-dev", github: "elixir-nx/nx", sparse: "exla"},
      # {:nx, path: "/home/sheldak/thesis/nx/nx", override: true}
      {:nx, path: "/Users/samuelheldak/studies/nx/nx", override: true}
      #      {:nx, path: "D:\\Agnieszka\\Documents\\Studia\\PracaInz\\nx\\nx"}
      #      {:nx, "~> 0.1.0-dev", github: "elixir-nx/nx", branch: "main", sparse: "nx"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end

defmodule Rabbits.MixProject do
  use Mix.Project

  def project do
    [
      app: :rabbits,
      version: "0.1.0",
      elixir: "~> 1.12",
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
      {:nx, "~> 0.1.0-dev", github: "elixir-nx/nx", sparse: "nx", override: true},
      {:distributed_simulator, path: "../.."}
    ]
  end
end

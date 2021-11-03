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
    if System.user_home() == "/Users/samuelheldak" do
      [
        {:nx, path: "/Users/samuelheldak/studies/nx/nx", override: true}
      ]
    else
      [
        {:nx, path: "/Users/agnieszkadutka/repos/inz/nx/nx", override: true}
      ]
    end
  end
end

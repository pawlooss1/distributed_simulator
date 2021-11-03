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
    if System.user_home() == "/Users/samuelheldak" do
      [
        {:nx, path: "/Users/samuelheldak/studies/nx/nx", override: true},
        {:distributed_simulator,
         path: "/Users/samuelheldak/studies/distributed_simulator", override: true}
      ]
    else
      [
        {:nx, path: "/Users/agnieszkadutka/repos/inz/nx/nx", override: true},
        {:distributed_simulator,
        path: "/Users/agnieszkadutka/repos/inz/distributed_simulator", override: true}
      ]
    end
  end
end

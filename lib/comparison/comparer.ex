defmodule Simulator.Comparer do
  @moduledoc """
  Comparison of two implementations.
  """

  alias Simulator.Nx
  alias Simulator.Standard

  def start() do
    fn -> Standard.start() end
    |> measure()
    |> then(fn time -> IO.puts("Standard: #{time}") end)

    fn -> Nx.start() end
    |> measure()
    |> then(fn time -> IO.puts("Nx:       #{time}") end)

    :ok
  end

  defp measure(function) do
    function
    |> :timer.tc()
    |> elem(0)
    |> Kernel./(1_000_000)
  end
end

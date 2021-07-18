defmodule Simulator.Launcher do
  @moduledoc """
  Choosing implementation.
  """

  alias Simulator.Nx
  alias Simulator.Evacuation
  alias Simulator.Standard
  alias Simulator.Comparer

  def start(:nx) do
    Nx.start()
  end

  def start(:evacuation) do
    Evacuation.start()
  end

  def start(:standard) do
    Standard.start()
  end

  def start(:comparison) do
    Comparer.start()
  end
end

defmodule Simulator.Launcher do
  @moduledoc """
  Choosing implementation.
  """

  alias Simulator.Nx
  alias Simulator.Standard

  def start(:nx) do
    Nx.start()
  end

  def start(:standard) do
    Standard.start()
  end
end

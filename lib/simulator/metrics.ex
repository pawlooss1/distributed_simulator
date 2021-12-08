defmodule Simulator.Metrics do
  @moduledoc """
  Module which should be `used` by exactly one module in every
  simulation. That module will be called Metrics module.

  TODO more
  """

  alias Simulator.Types

  @callback calculate_metrics(
              metrics :: Nx.t(),
              old_grid :: Nx.t(),
              old_objects_state :: Nx.t(),
              grid :: Nx.t(),
              objects_state :: Nx.t(),
              iterations :: Types.index()
            ) ::
              metrics :: Nx.t()

  defmacro __using__(_opts) do
    quote location: :keep do
      @behaviour unquote(__MODULE__)
    end
  end
end

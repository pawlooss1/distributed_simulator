defmodule Simulator.PlanCreator do
  @moduledoc """
  Module which should be `used` by exactly one module in every
  simulation. That module will be called PlanCreator module.

  Using module have to implement function `create_plan/5` which will
  be responsible for creating plans for every dynamic object in the
  simulation. Function should return a tuple `{direction, plan}`
  where `plan` is a one dimensional tensor with two elements:
  `[action, consequence]`.

  See `Evacuation.PlanCreator` in the `examples` directory for
  the exemplary usage.
  """

  alias Simulator.Types

  @callback create_plan(
              grid :: Nx.t(),
              objects_state :: Nx.t(),
              iteration :: Types.index(),
              rng :: Nx.t()
            ) ::
              {grid :: Nx.t(), rng :: Nx.t()}

  defmacro __using__(_opts) do
    quote location: :keep do
      @behaviour unquote(__MODULE__)
    end
  end
end

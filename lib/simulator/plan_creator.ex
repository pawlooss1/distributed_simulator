defmodule Simulator.PlanCreator do
  @moduledoc """
  Module which should be `used` by exactly one module in every
  simulation. That module will be called PlanCreator module.

  Using module have to implement function `create_plans/5` which will
  be responsible for creating plans for every dynamic object in the
  simulation. Only `plans` in the returned tuple should be changed.
  Plan (tensor [direction, action, consequence]) should be put in
  the place: `plans[x_index][y_index]`.

  See `Evacuation.PlanCreator` in the `examples` directory for
  the exemplary usage.
  """

  alias Simulator.Types

  @callback create_plan(
              x_index :: Types.index(),
              y_index :: Types.index(),
              plans :: Nx.t(),
              grid :: Nx.t(),
              object_data :: Nx.t(),
              iterations :: Types.index()
            ) ::
              {
                x_index :: Types.index(),
                y_index :: Types.index(),
                plans :: Nx.t(),
                grid :: Nx.t(),
                # object_data :: Nx.t(),
                iterations :: Types.index()
              }

  defmacro __using__(_opts) do
    quote location: :keep do
      @behaviour unquote(__MODULE__)
    end
  end
end

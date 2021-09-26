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

  @type x_index :: Type.index
  @type y_index :: Type.index
  @type grid :: Nx.t
  @type plans :: Nx,t
  @type iteration :: Type.index

  @callback create_plan(x_index(), y_index, grid(), plans(), iteration()) ::
              {x_index(), y_index, grid(), plans(), iteration()}

  defmacro __using__(_opts) do
    quote location: :keep do
      @behaviour unquote(__MODULE__)
    end
  end
end

defmodule Simulator.PlanResolver do
  @moduledoc """
  Module which should be `used` by exactly one module in every
  simulation. That module will be called PlanResolver module.

  It has to implement three functions:
  - `is_update_valid?/2` - which will be responsible for checking
    whether the `action` can be applied to the `object`;
  - `apply_action/3` - which should return new object and state for the location of the action of the plan.
  - `apply_consequence/3` - which should return new object and state for the old object location.

  See `Evacuation.PlanResolver` in the `examples` directory for
  the exemplary usage.
  """

  @callback is_update_valid?(action :: Nx.t(), object :: Nx.t()) :: Nx.t()
  @callback apply_action(
              object :: Nx.t(),
              plan :: Nx.t(),
              old_state :: Nx.t()
            ) :: {new_object :: integer(), new_state :: Nx.t()}
  @callback apply_consequence(
              object :: Nx.t(),
              plan :: Nx.t(),
              old_state :: Nx.t()
            ) :: {new_object :: integer(), new_state :: Nx.t()}

  defmacro __using__(_opts) do
    quote location: :keep do
      @behaviour unquote(__MODULE__)
    end
  end
end

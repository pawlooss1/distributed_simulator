defmodule Rabbits.Constants do
  use Simulator.Constants

  @impl true
  defmacro define_constants do
    quote do
      @rabbit 1
      @lettuce 2

      @add_rabbit 1
      @add_lettuce 2
      @remove_rabbit 3
      @remove_lettuce 4

      @lettuce_growth_factor 2
      @rabbit_start_energy 5

      @rabbit_signal -5
      @lettuce_signal 10
    end
  end
end

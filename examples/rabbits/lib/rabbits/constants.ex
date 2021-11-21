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
      @keep_rabbit 5

      @rabbit_move Nx.tensor([@add_rabbit, @remove_rabbit])
      @rabbit_die Nx.tensor([@remove_rabbit, @keep])
      @rabbit_procreate Nx.tensor([@add_rabbit, @keep])
      @rabbit_rest Nx.tensor([@keep_rabbit, @keep])

      @lettuce_grow Nx.tensor([@add_lettuce, @keep])

      @lettuce_growth_factor 2
      @rabbit_reproduction_energy 8
      @rabbit_start_energy 12

      @move_cost 1
      @lettuce_energy_boost 1

      @rabbit_signal -5
      @lettuce_signal 10
    end
  end
end

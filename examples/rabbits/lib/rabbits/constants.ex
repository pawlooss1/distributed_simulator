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

      @rabbit_move 0x01_03_00 # Nx.tensor([@add_rabbit, @remove_rabbit])
      @rabbit_die 0x03_00_00 # Nx.tensor([@remove_rabbit, @keep])
      @rabbit_procreate 0x01_00_00 # Nx.tensor([@add_rabbit, @keep])
      @rabbit_rest 0x05_00_00 # Nx.tensor([@keep_rabbit, @keep])

      @lettuce_grow 0x02_00_00 # Nx.tensor([@add_lettuce, @keep])

      @lettuce_growth_factor 2
      @rabbit_reproduction_energy 9
      @rabbit_start_energy 8

      @move_cost 1
      @lettuce_energy_boost 1

      @rabbit_signal -10
      @lettuce_signal 20
    end
  end
end

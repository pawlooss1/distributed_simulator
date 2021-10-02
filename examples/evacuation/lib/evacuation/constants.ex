defmodule Evacuation.Constants do
  use Simulator.Constants

  @impl true
  defmacro define_constants do
    quote do
      @person 1
      @obstacle 2
      @exit 3
      @fire 4

      @fire_spreading_frequency 5

      @exit_signal 30
      @fire_signal -30
    end
  end
end

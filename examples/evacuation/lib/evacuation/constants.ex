defmodule Evacuation.Constants do
  use Simulator.Constants

  @impl true
  defmacro define_constants do
    quote do
      @person 1
      @obstacle 2
      @exit 3
      @fire 4

      @add_person 1
      @remove_person 2
      @create_fire 3

      @person_move 0b00000001_00000010_00000000
      @fire_spread 0b00000011_00000000_00000000

      @fire_spreading_frequency 2

      @exit_signal 30
      @fire_signal -30
    end
  end
end

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

      @person_move 0x01_02_00
      @fire_spread 0x03_00_00

      @fire_spreading_frequency 2

      @exit_signal 30
      @fire_signal -30
    end
  end
end

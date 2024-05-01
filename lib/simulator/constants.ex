defmodule Simulator.Constants do
  @moduledoc """
  Module which should be `used` in the Constant module in every
  simulation. Constant module provides other modules with useful
  constants (as Nx requires numbers, it is a workaround to make code
  more readables).

  `Using` the module requires implementing `define_constants/0`
  macro. Its exemplary body can be seen in `Evacuation.Constants`
  module in the `examples` directory. Attributes inside the macro
  are specific to the simulation.

  After defining Constant module (`using` this one), it can be `used`
  by other modules in the simulation to provide them with needed
  constants (the ones defined below and other defined by the
  framework user).
  """

  @macrocallback define_constants() :: Macro.t()
  @optional_callbacks define_constants: 0

  defmacro __using__(_opts) do
    quote location: :keep do
      @behaviour unquote(__MODULE__)

      defmacro __using__(_opts) do
        quote location: :keep do
          @grid_type {:s, 64}
          # constants set in simulation's config file
          @max_iterations Application.compile_env!(:distributed_simulator, :max_iterations)

          @signal_suppression_factor Application.compile_env!(
                                       :distributed_simulator,
                                       :signal_suppression_factor
                                     )
          @signal_attenuation_factor Application.compile_env!(
                                       :distributed_simulator,
                                       :signal_attenuation_factor
                                     )
          @object_vector_length Application.compile_env(
                                  :distributed_simulator,
                                  :object_vector_length,
                                  1
                                )
          # directions
          @direction_filter 0xff_00_00_00
          @direction_vectors Nx.complex(
            Nx.tensor([1, 0.7071067690849304, 0, -0.7071067690849304, -1, -0.7071067690849304, 0, 0.7071067690849304]),
            Nx.tensor([0, 0.7071067690849304, 1, 0.7071067690849304, 0, -0.7071067690849304, -1, -0.7071067690849304])
          )

          @dir_stay 0x00_00_00_00
          @dir_right 0x01_00_00_00
          @dir_top_right 0x02_00_00_00
          @dir_top 0x03_00_00_00
          @dir_top_left 0x04_00_00_00
          @dir_left 0x05_00_00_00
          @dir_bottom_left 0x06_00_00_00
          @dir_bottom 0x07_00_00_00
          @dir_bottom_right 0x08_00_00_00

          @directions_list [
            @dir_right,
            @dir_top_right,
            @dir_top,
            @dir_top_left,
            @dir_left,
            @dir_bottom_left,
            @dir_bottom,
            @dir_bottom_right
          ]

          @directions Nx.tensor(@directions_list)

          @reverse_directions Nx.tensor([
            @dir_left,
            @dir_bottom_left,
            @dir_bottom,
            @dir_bottom_right,
            @dir_right,
            @dir_top_right,
            @dir_top,
            @dir_top_left
          ])

          # plans
          @rejected 0
          @accepted 1

          # object
          @object_filter 0xff
          @empty 0

          # action
          @action_object_filter 0xff_ff_ff
          @keep 0

          # plan
          @plan_filter 0xff_ff_ff_00
          @plan_keep Nx.tensor([@keep, @keep])

          # for signals
          @infinity 1_000_000_000

          # grid creation
          @margin_size 1

          # positions
          @consequence_position 8
          @action_position 16
          @direction_position 24

          # state_mapping
          @identity 0

          unquote(__MODULE__).define_constants()
        end
      end

      defmacro define_constants do
      end

      defoverridable define_constants: 0
    end
  end
end

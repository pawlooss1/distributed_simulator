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
          @dir_stay 0
          @dir_top 1
          @dir_top_right 2
          @dir_right 3
          @dir_bottom_right 4
          @dir_bottom 5
          @dir_bottom_left 6
          @dir_left 7
          @dir_top_left 8

          @directions [
            @dir_top,
            @dir_top_right,
            @dir_right,
            @dir_bottom_right,
            @dir_bottom,
            @dir_bottom_left,
            @dir_left,
            @dir_top_left
          ]

          @direction_indices Nx.tensor([0, 1, 2, 3, 5, 6, 7, 8])

          # plans
          @rejected 0
          @accepted 1

          # object
          @empty 0

          # action
          @keep 0

          # plan
          @plan_keep Nx.tensor([@keep, @keep])

          # for signals
          @infinity 1_000_000_000

          # grid creation
          @margin_size 3

          # positions
          @direction_position 12
          @action_position 8
          @consequence_position 4

          # filters
          @leave_plan_filter 0b1111_1111_1111_0000
          @leave_direction_filter 0b1111_0000_0000_0000
          @leave_undirected_plan_filter 0b0000_1111_1111_0000
          @leave_object_filter 0b0000_0000_0000_1111
          @leave_consequence_filter 0b0000_0000_1111_0000
          @cut_direction_filter 0b0000_1111_1111_1111

          @neigh_to_row_filter Nx.tensor([
                                 @leave_plan_filter,
                                 @leave_plan_filter,
                                 @leave_plan_filter,
                                 @leave_plan_filter,
                                 @leave_object_filter,
                                 @leave_plan_filter,
                                 @leave_plan_filter,
                                 @leave_plan_filter,
                                 @leave_plan_filter
                               ])

          unquote(__MODULE__).define_constants()
        end
      end

      defmacro define_constants do
      end

      defoverridable define_constants: 0
    end
  end
end

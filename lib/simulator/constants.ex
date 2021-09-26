defmodule Simulator.Constants do
  @macrocallback define_constants() :: Macro.t()
  @optional_callbacks define_constants: 0

  defmacro __using__(_opts) do
    quote location: :keep do
      @behaviour unquote(__MODULE__)

      defmacro __using__(_opts) do
        quote location: :keep do
          @module_prefix Application.compile_env!(:distributed_simulator, :module_prefix)

          @max_iterations Application.compile_env!(:distributed_simulator, :max_iterations)
          @signal_suppression_factor Application.compile_env!(
                                       :distributed_simulator,
                                       :signal_suppression_factor
                                     )
          @signal_attenuation_factor Application.compile_env!(
                                       :distributed_simulator,
                                       :signal_attenuation_factor
                                     )

          @dir_stay 0
          @dir_top 1
          @dir_top_right 2
          @dir_right 3
          @dir_bottom_right 4
          @dir_bottom 5
          @dir_bottom_left 6
          @dir_left 7
          @dir_top_left 8

          @empty 0

          @infinity 1_000_000_000

          unquote(__MODULE__).define_constants()
        end
      end

      defmacro define_constants do
      end

      defoverridable define_constants: 0
    end
  end
end

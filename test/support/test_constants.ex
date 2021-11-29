defmodule Simulator.TestConstants do
  @moduledoc """
  Constants needed in tests.
  """
  
  use Simulator.Constants

  @impl true
  defmacro define_constants do
    quote do
      @object_1 1
      @object_2 2

      @add_1 1
      @remove_1 2
      @remove_2 3

      @move Nx.tensor([@add_1, @remove_1])
      @destroy Nx.tensor([@remove_2, @keep])

      @full_plan_keep [@dir_stay, @keep, @keep]
		end
  end
end

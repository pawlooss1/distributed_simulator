defmodule Simulator.PlanCreator do
  alias Simulator.Types

  @callback create_plan(Types.index(), Types.index(), Nx.t(), Nx.t(), Types.index()) ::
              {Types.index(), Types.index(), Nx.t(), Nx.t(), Types.index()}

  defmacro __using__(_opts) do
    quote location: :keep do
      @behaviour unquote(__MODULE__)
    end
  end
end

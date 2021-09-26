defmodule Simulator.PlanCreator do
  @type index :: non_neg_integer

  @callback create_plan(index(), index(), Nx.t(), Nx.t(), index()) ::
              {index(), index(), Nx.t(), Nx.t(), index()}

  defmacro __using__(_opts) do
    quote location: :keep do
      @behaviour unquote(__MODULE__)
    end
  end
end

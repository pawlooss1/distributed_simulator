defmodule Simulator.PlanCreator do
  @type index :: non_neg_integer

  @callback create_plan(index(), index(), Nx.t(), Nx.t(), index()) ::
      {index(), index(), Nx.t(), Nx.t(), index()}
end

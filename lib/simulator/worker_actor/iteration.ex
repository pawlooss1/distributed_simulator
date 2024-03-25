defmodule Iteration do
  use Simulator.BaseConstants

  import Nx.Defn
  import Simulator.Helpers

  alias Simulator.WorkerActor.{Consequences, Plans, Signal}

  @spec compute(
          Types.index(),
          Nx.t(),
          Nx.t(),
          Nx.t(),
          Nx.fun(),
          Nx.fun(),
          Nx.fun(),
          Nx.fun(),
          Nx.fun(),
          Nx.fun(),
          Nx.fun()
        ) :: {Nx.t(), Nx.t(), Nx.t()}
  defn compute(
         iteration,
         grid,
         objects_state,
         rng,
         create_plan,
         action_mappings,
         map_state_action,
         consequence_mappings,
         map_state_consequence,
         signal_generators,
         signal_factors
       ) do
    plans = Plans.create_plans(iteration, grid, objects_state, rng, create_plan)

    {updated_objects, updated_objects_state} =
      Plans.process_plans(plans, objects_state, rng, action_mappings, map_state_action)

    {updated_objects, updated_objects_state} =
      Consequences.process_consequences(updated_objects, updated_objects_state, consequence_mappings, map_state_consequence)

    updated_grid = Nx.put_slice(grid, [0, 0, 0], add_dimension(updated_objects))

    signal_update = Signal.calculate_signal_updates(updated_grid, signal_generators)
    final_grid = Signal.apply_signal_update(updated_grid, signal_update, signal_factors)
    {final_grid, updated_objects_state, rng}
  end
end

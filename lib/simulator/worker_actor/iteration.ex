defmodule Iteration do
  use Simulator.BaseConstants

  import Nx.Defn

  alias Simulator.WorkerActor.{Consequences, Plans, Signal}

  @spec compute(Types.index(), Nx.t(), Nx.t(), fun(), fun(), fun(), fun(), fun(), fun()) :: Nx.t()
  defn compute(
         iteration,
         grid,
         objects_state,
         create_plan,
         is_update_valid?,
         apply_action,
         apply_consequence,
         generate_signal,
         signal_factor
       ) do
    plans = Plans.create_plans(iteration, grid, objects_state, create_plan)

    {updated_grid, accepted_plans, updated_objects_state} =
      Plans.process_plans(
        grid,
        plans,
        objects_state,
        is_update_valid?,
        apply_action
      )

    {updated_grid, updated_objects_state} =
      Consequences.apply_consequences(
        updated_grid,
        updated_objects_state,
        plans,
        accepted_plans,
        apply_consequence
      )

    signal_update = Signal.calculate_signal_updates(updated_grid, generate_signal)
    final_grid = Signal.apply_signal_update(grid, signal_update, signal_factor)
    {final_grid, updated_objects_state}
  end
end

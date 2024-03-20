defmodule Iteration do
  use Simulator.BaseConstants

  import Nx.Defn

  alias Simulator.WorkerActor.{Consequences, Plans, Signal}

  @spec compute(
          Types.index(),
          Nx.t(),
          Nx.t(),
          Nx.t(),
          Nx.fun(),
          fun(),
          fun(),
          fun(),
          fun(),
          fun()
        ) :: {Nx.t(), Nx.t(), Nx.t()}
  defn compute(
         iteration,
         grid,
         objects_state,
         rng,
         create_plan,
         action_mappings,
         map_state,
         apply_consequence,
         generate_signal,
         signal_factor
       ) do
    plans = Plans.create_plans(iteration, grid, objects_state, rng, create_plan)

    {order, rng} = Nx.Random.shuffle(rng, Nx.tensor(@directions))

    {updated_grid, updated_objects_state} =
      Plans.process_plans(grid, objects_state, rng, action_mappings, map_state)

    # {updated_grid, updated_objects_state} =
    #   Consequences.apply_consequences(
    #     updated_grid,
    #     updated_objects_state,
    #     plans,
    #     plans,
    #     apply_consequence
    #   )

    # signal_update = Signal.calculate_signal_updates(updated_grid, generate_signal)
    # final_grid = Signal.apply_signal_update(updated_grid, signal_update, signal_factor)
    # {final_grid, updated_objects_state, rng}
  end
end

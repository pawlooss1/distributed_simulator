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
         is_update_valid?,
         apply_action,
         apply_consequence,
         generate_signal,
         signal_factor
       ) do
    plans = Plans.create_plans_2(iteration, grid, objects_state, rng, create_plan)

    # {order, rng} = Nx.Random.shuffle(rng, Nx.tensor([0, 1, 2, 3, 5, 6, 7, 8]))

    # {updated_grid, accepted_plans, updated_objects_state} =
    #   Plans.process_plans_2(
    #     grid,
    #     plans,
    #     objects_state,
    #     order,
    #     is_update_valid?,
    #     apply_action
    #   )

    # {updated_grid, updated_objects_state} =
    #   Consequences.apply_consequences_2(
    #     updated_grid,
    #     updated_objects_state,
    #     plans,
    #     accepted_plans,
    #     apply_consequence
    #   )

    # signal_update = Signal.calculate_signal_updates(updated_grid, generate_signal)
    # final_grid = Signal.apply_signal_update(updated_grid, signal_update, signal_factor)
    # {final_grid, updated_objects_state, rng}
    plans
  end
end

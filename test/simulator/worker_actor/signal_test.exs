defmodule Simulator.WorkerActor.SignalTest do
  @moduledoc """
  Module responsible for testing functions responsible for signal.
  """

  use ExUnit.Case, async: true
  use Simulator.TestConstants

  import Simulator.{ScenarioElements, TestCallbacks}

  alias Simulator.WorkerActor.{Consequences, Plans, Signal}

  test "calculate_signal_updates/2 creates signal update correctly" do
    {updated_grid, accepted_plans, updated_objects_state} =
      Plans.process_plans(grid(), plans(), objects_state(), &is_update_valid?/2, &apply_action/3)

    {updated_grid, _objects_state} =
      Consequences.apply_consequences(
        updated_grid,
        updated_objects_state,
        plans(),
        accepted_plans,
        &apply_consequence/3
      )

    expected_signal_update =
      [
        [
          [0, 0, 0, 0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0, 0, 0, 0]
        ],
        [
          [0, 0, 0, 0, 0, 0, 0, 0, 0],
          [0, 0, 0, 3, 10, 2, 0, 0, 0],
          [0, 0, 0, 9, 0, 10, 0, 0, 0],
          [0, 0, 0, 10, 0, 0, 10, 5, 0],
          [0, 0, 0, 0, 0, 0, 0, 8, 0],
          [0, 0, 0, 0, 0, 0, 0, 0, 0]
        ],
        [
          [0, 0, 0, 0, 0, 0, 0, 0, 0],
          [0, 0, 0, 10, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0, 0, 0, 0],
          [0, 0, 10, 0, -10, 0, 0, 10, 0],
          [0, 10, 0, 0, 0, -10, 0, 0, 0],
          [0, 0, 0, 0, 0, 0, 0, 0, 0]
        ],
        [
          [0, 0, 0, 0, 0, 0, 0, 0, 0],
          [0, 3, 10, 0, 0, 0, 0, 0, 0],
          [0, 10, 0, 0, 0, 0, 0, 0, 0],
          [0, 5, 0, -10, 0, 0, 0, 0, 10],
          [0, 0, 0, 0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0, 0, 0, 0]
        ],
        [
          [0, 0, 0, 0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0, 0, 0, 0]
        ]
      ]
      |> Nx.tensor()

    signal_update = Signal.calculate_signal_updates(updated_grid, &generate_signal/1)
    assert signal_update == expected_signal_update
  end

  test "apply_signal_update/3 updates signal correctly" do
    {updated_grid, accepted_plans, updated_objects_state} =
      Plans.process_plans(grid(), plans(), objects_state(), &is_update_valid?/2, &apply_action/3)

    {updated_grid, _objects_state} =
      Consequences.apply_consequences(
        updated_grid,
        updated_objects_state,
        plans(),
        accepted_plans,
        &apply_consequence/3
      )

    signal_update = Signal.calculate_signal_updates(updated_grid, &generate_signal/1)

    expected_grid =
      [
        [
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0]
        ],
        [
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@empty, 0, 0, 0, 3, 0, 0, 0, 0],
          [@empty, 0, 0, 3, 0, 4, 1, 0, 0],
          [@empty, 0, 0, 5, 1, 1, 4, 4, 0],
          [@object_1, 0, 0, 0, 0, 0, 0, 2, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0]
        ],
        [
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@empty, 0, 0, 3, 0, 0, 0, 0, 0],
          [@object_1, 0, 0, 0, 0, 0, 0, 0, 0],
          [@empty, 2, 3, 0, -3, 0, 0, 3, 0],
          [@empty, 3, 0, 0, 0, -3, 0, 0, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0]
        ],
        [
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@empty, 0, 3, 0, 0, 0, 0, 0, 0],
          [@empty, 3, 0, 0, 0, 0, 0, 0, 0],
          [@empty, 1, 0, -3, 0, 0, 0, 0, 3],
          [@object_2, 2, 0, 0, 0, 0, 0, 2, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0]
        ],
        [
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0],
          [@empty, 0, 0, 0, 0, 0, 0, 0, 0]
        ]
      ]
      |> Nx.tensor()

    updated_grid = Signal.apply_signal_update(updated_grid, signal_update, &signal_factor/1)
    assert updated_grid == expected_grid
  end
end

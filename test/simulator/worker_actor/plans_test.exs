defmodule Simulator.WorkerActor.PlansTest do
  @moduledoc """
  Module responsible for testing functions responsible for plans.
  """

  use ExUnit.Case, async: true
  use Simulator.TestConstants

  import Simulator.{ScenarioElements, TestCallbacks}

  alias Simulator.WorkerActor.Plans

  test "create_plans/4 creates plans correctly" do
    assert Plans.create_plans(0, grid(), 0, &create_plan/5) == plans()
  end

  test "process_plans/5 processes plans correctly" do
    expected_grid =
      grid()
      |> Nx.put_slice([1, 4, 0], Nx.tensor([[[@object_1]]]))
      |> Nx.put_slice([2, 2, 0], Nx.tensor([[[@object_1]]]))
      |> Nx.put_slice([2, 1, 0], Nx.tensor([[[@empty]]]))
      |> Nx.put_slice([2, 3, 0], Nx.tensor([[[@empty]]]))

    expected_accepted_plans =
      [
        [0, 0, 0, 0, 0, 0],
        [0, 0, 1, 1, 0, 0],
        [0, 1, 0, 1, 0, 0],
        [0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0]
      ]
      |> Nx.tensor()

    expected_objects_state =
      [
        [0, 0, 0, 0, 0, 0],
        [0, 0, 10, 6, 5, 0],
        [0, 0, 9, 0, 0, 0],
        [0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0]
      ]
      |> Nx.tensor()

    {updated_grid, accepted_plans, updated_objects_state} =
      Plans.process_plans(grid(), plans(), objects_state(), &is_update_valid?/2, &apply_action/3)

    assert updated_grid == expected_grid
    assert accepted_plans == expected_accepted_plans
    assert updated_objects_state == expected_objects_state
  end
end

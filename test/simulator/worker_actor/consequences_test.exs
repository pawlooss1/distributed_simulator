defmodule Simulator.WorkerActor.ConsequencesTest do
  @moduledoc """
  Module responsible for testing a function responsible for applying
  consequences.
  """

  use ExUnit.Case, async: true
  use Simulator.TestConstants

  import Simulator.{ScenarioElements, TestCallbacks}

  alias Simulator.WorkerActor.{Plans, Consequences}

  test "apply_consequences/5 applies consequences correctly" do
    {updated_grid, accepted_plans, updated_objects_state} =
      Plans.process_plans(grid(), plans(), objects_state(), &is_update_valid?/2, &apply_action/3)

    expected_grid =
      updated_grid
      |> Nx.put_slice([1, 2, 0], Nx.tensor([[[@empty]]]))
      |> Nx.put_slice([1, 3, 0], Nx.tensor([[[@empty]]]))

    expected_objects_state =
      updated_objects_state
      |> Nx.put_slice([1, 2], Nx.tensor([[0]]))
      |> Nx.put_slice([1, 3], Nx.tensor([[0]]))

    {updated_grid, updated_objects_state} =
      Consequences.apply_consequences(
        updated_grid,
        updated_objects_state,
        plans(),
        accepted_plans,
        &apply_consequence/3
      )

    assert updated_grid == expected_grid
    assert updated_objects_state == expected_objects_state
  end
end

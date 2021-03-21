defmodule WorkerActor do
  @moduledoc false

  import Position
  import Utils

  @max_iterations 5

  @doc """
  For now abandon 'Alternative' from discarded plans in remote plans (no use of it in Mock example). Currently there is
  also no use of :remote_signal and :remote_cell_contents states.
  Returns tuple: {{action position, Action}, {consequence position, Consequence}}
  """
  def listen grid, neighbors do
    receive do
      {:start_iteration, iteration} when iteration > @max_iterations ->
        IO.puts "terminating worker"

      {:start_iteration, iteration} ->
        plans =
          Map.keys(grid)
          |> Enum.map(fn position -> createPlan position, grid, neighbors end)

        distributePlans iteration, plans

        listen grid, neighbors

      {:remote_plans, iteration, plans} ->
        {updatedGrid, acceptedPlans} = processPlans grid, Enum.shuffle(plans)
        consequences = Enum.map(acceptedPlans, fn {_, consequence} -> consequence end)

        distributeConsequences iteration, consequences

        listen updatedGrid, neighbors

      {:remote_consequences, iteration, consequences} ->
        updatedGrid = applyConsequences grid, consequences
        writeToFile updatedGrid, "grid_#{iteration}"

        send self(), {:start_iteration, iteration + 1}

        listen updatedGrid, neighbors
    end
  end

  def createPlan cellPosition, grid, neighbors do
    case Map.get(grid, cellPosition) do
      :mock -> randomMove cellPosition, grid, neighbors
      _     -> {}
    end
  end

  @doc """
  For now abandon 'Alternative' in plans (not appearing in Mock example)
  Returns tuple: {{action position, Action}, {consequence position, Consequence}}
  """
  def randomMove cellPosition, grid, neighbors do
    availableDirections =
      Map.get(neighbors, cellPosition)
      |> Enum.filter(fn {_, position} -> Map.get(grid, position) == :empty end)
      |> Enum.map(fn {direction, _} -> direction end)

    case availableDirections do
      [] -> {}
      _  ->
        direction = Enum.random(availableDirections)
        {{shift(cellPosition, direction), :mock}, {cellPosition, :empty}}
    end
  end

  def distributePlans iteration, plans do
    send self(), {:remote_plans, iteration, plans}
  end

  def processPlans grid, [] do
    {grid, []}
  end
  def processPlans grid, [plan | plans] do
    if validatePlan grid, plan do
      {{target, action}, _} = plan
      {updatedGrid, acceptedPlans} = processPlans(%{grid | target => action}, plans)
      {updatedGrid, [plan | acceptedPlans]}
    else
      processPlans grid, plans
    end
  end

  def validatePlan grid, plan do
    case plan do
      {}               -> false
      {{target, _}, _} -> Map.get(grid, target) == :empty
    end
  end

  def distributeConsequences iteration, consequences do
    send self(), {:remote_consequences, iteration, consequences}
  end

  def applyConsequences grid, [] do
    grid
  end
  def applyConsequences grid, [consequence | consequences] do
    {target, action} = consequence
    applyConsequences %{grid | target => action}, consequences
  end
end

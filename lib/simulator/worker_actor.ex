defmodule Simulator.WorkerActor do
  @moduledoc false

  use GenServer
  use Simulator.BaseConstants

  import Nx.Defn
  import Simulator.{Cell, Helpers, Printer}

  alias Simulator.Phase.{RemoteConsequences, RemotePlans, RemoteSignal, StartIteration}

  def start(grid: grid) do
    GenServer.start(__MODULE__, grid)
  end

  @impl true
  def init(grid) do
    send(self(), :start_iteration)

    {:ok, %{grid: grid, iteration: 1}}
  end

  @doc """
  For now abandon 'Alternative' from discarded plans in remote plans (no use of it in Mock example).
  Currently there is also no use of :remote_signal and :remote_cell_contents states.
  Returns tuple: {{action position, Action}, {consequence position, Consequence}}
  """
  @impl true
  def handle_info(:start_iteration, %{iteration: iteration} = state)
      when iteration > @max_iterations do
    {:stop, :normal, state}
  end

  def handle_info(:start_iteration, %{grid: grid, iteration: iteration} = state) do
    create_plan = &@module_prefix.PlanCreator.create_plan/5
    plans = StartIteration.create_plans(iteration, grid, create_plan)

    distribute_plans(plans)
    {:noreply, state}
  end

  def handle_info({:remote_plans, plans}, %{grid: grid} = state) do
    {updated_grid, accepted_plans} = RemotePlans.process_plans(grid, plans)

    # todo - now action+cons applied at once
    # todo could apply alternatives as well if those existed, without changing input :D
    #
    distribute_consequences(plans, accepted_plans)
    {:noreply, %{state | grid: updated_grid}}
  end

  def handle_info({:remote_consequences, plans, accepted_plans}, %{grid: grid} = state) do
    updated_grid = RemoteConsequences.apply_consequences(grid, plans, accepted_plans)

    generate_signal = &@module_prefix.Cell.generate_signal/1
    signal_update = RemoteConsequences.calculate_signal_updates(updated_grid, generate_signal)

    distribute_signal(signal_update)
    {:noreply, %{state | grid: updated_grid}}
  end

  def handle_info({:remote_signal, signal_update}, state) do
    %{grid: grid, iteration: iteration} = state

    signal_factor = &@module_prefix.Cell.signal_factor/1
    updated_grid = RemoteSignal.apply_signal_update(grid, signal_update, signal_factor)

    write_to_file(updated_grid, "grid_#{iteration}")

    start_next_iteration()
    {:noreply, %{state | grid: updated_grid, iteration: iteration + 1}}
  end

  # Sends each plan to worker managing cells affected by this plan.
  defp distribute_plans(plans) do
    send(self(), {:remote_plans, plans})
  end

  # Sends each consequence to worker managing cells affected by this plan consequence.
  defp distribute_consequences(plans, accepted_plans) do
    send(self(), {:remote_consequences, plans, accepted_plans})
  end

  # Sends each signal to worker managing cells affected by this signal.
  defp distribute_signal(signal_update) do
    send(self(), {:remote_signal, signal_update})
  end

  # Starts the next iteration by sending message.
  defp start_next_iteration() do
    send(self(), :start_iteration)
  end
end

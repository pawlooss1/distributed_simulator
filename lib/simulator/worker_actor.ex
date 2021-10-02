defmodule Simulator.WorkerActor do
  @moduledoc """
  GenServer responsible for simulating one shard.

  There are four phases of every iteration:
  - `:start_iteration` - if iteration's number does not exceed the
    maxium number of iterations set in the cofiguration, plans are
    created and distributed to the neighboring shards;
  - `:remote_plans` - plans are processed. Some of them are accepted,
    some discarded. Result of the processing is distributed among
    neighboring shards;
  - `:remote_consequences` - consequences derived from the accepted
    plans are applied to the grid. Additionally, signal update is
    calculated and distributed to the neighboring shards;
  - `:remote_signal` - signal is applied to the grid. Next iteration
    is started.
  """

  use GenServer
  use Simulator.BaseConstants

  alias Simulator.Phase.{RemoteConsequences, RemotePlans, RemoteSignal, StartIteration}
  alias Simulator.Printer

  @doc """
  Starts the WorkerActor.

  TODO use some supervisor.
  """
  @spec start(keyword(Nx.t())) :: GenServer.on_start()
  def start(grid: grid) do
    GenServer.start(__MODULE__, grid)
  end

  @impl true
  def init(grid) do
    send(self(), :start_iteration)

    {:ok, %{grid: grid, iteration: 1}}
  end

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

  # For now abandon 'Alternative' from discarded plans in remote plans (no use of it in the
  # current examples). Currently, there is also no use of :remote_signal and :remote_cell_contents
  # states. Returns tuple: {{action position, Action}, {consequence position, Consequence}}
  def handle_info({:remote_plans, plans}, %{grid: grid} = state) do
    {updated_grid, accepted_plans} = RemotePlans.process_plans(grid, plans)

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

    Printer.write_to_file(updated_grid, "grid_#{iteration}")

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

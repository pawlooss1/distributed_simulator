defmodule Simulator.Callbacks do
  @module_cell Application.compile_env(:distributed_simulator, :module_cell, nil)
  @module_metrics Application.compile_env(:distributed_simulator, :module_metrics, nil)
  @module_plan_creator Application.compile_env(:distributed_simulator, :module_plan_creator, nil)
  @module_plan_resolver Application.compile_env(
                          :distributed_simulator,
                          :module_plan_resolver,
                          nil
                        )

  defmacro generate_signal(object) do
    if is_nil(@module_cell) do
      throw("Function generate_signal/1 is not implemented!")
    else
      quote do
        cell = Application.get_env(:distributed_simulator, :module_cell)
        cell.generate_signal(unquote(object))
      end
    end
  end

  defmacro signal_factor(object) do
    if is_nil(@module_cell) do
      throw("Function signal_factor/1 is not implemented!")
    else
      quote do
        cell = Application.get_env(:distributed_simulator, :module_cell)
        cell.signal_factor(unquote(object))
      end
    end
  end

  defmacro calculate_metrics(
             metrics,
             old_grid,
             old_objects_state,
             grid,
             objects_state,
             iterations
           ) do
    if is_nil(@module_metrics) do
      throw("Function calculate_metrics/6 is not implemented!")
    else
      quote do
        metrics = Application.get_env(:distributed_simulator, :module_metrics)

        metrics.calculate_metrics(
          unquote(metrics),
          unquote(old_grid),
          unquote(old_objects_state),
          unquote(grid),
          unquote(objects_state),
          unquote(iterations)
        )
      end
    end
  end

  defmacro create_plan(grid, objects_state, iterations, rng) do
    if is_nil(@module_plan_creator) do
      throw("Function create_plan/4 is not implemented!")
    else
      quote do
        plan_creator = Application.get_env(:distributed_simulator, :module_plan_creator)

        plan_creator.create_plan(
          unquote(grid),
          unquote(objects_state),
          unquote(iterations),
          unquote(rng)
        )
      end
    end
  end

  defmacro action_mappings() do
    if is_nil(@module_plan_resolver) do
      throw("Function action_mappings/0 is not implemented!")
    else
      quote do
        plan_resolver = Application.get_env(:distributed_simulator, :module_plan_resolver)
        plan_resolver.action_mappings()
      end
    end
  end

  defmacro map_state(objects_state, fun_label) do
    if is_nil(@module_plan_resolver) do
      throw("Function map_state/2 is not implemented!")
    else
      quote do
        plan_resolver = Application.get_env(:distributed_simulator, :module_plan_resolver)
        plan_resolver.map_state(unquote(objects_state), unquote(fun_label))
      end
    end
  end

  defmacro apply_consequence(object, plan, old_state) do
    if is_nil(@module_plan_resolver) do
      throw("Function apply_consequence/3 is not implemented!")
    else
      quote do
        plan_resolver = Application.get_env(:distributed_simulator, :module_plan_resolver)
        plan_resolver.apply_consequence(unquote(object), unquote(plan), unquote(old_state))
      end
    end
  end
end

import Config

if config_env() == :test do
  config :distributed_simulator,
    max_iterations: 25,
    module_cell: Test.Cell,
    module_metrics: Test.Metrics,
    module_plan_creator: Test.PlanCreator,
    module_plan_resolver: Test.PlanResolver,
    signal_attenuation_factor: 0.4,
    signal_suppression_factor: 0.8
end

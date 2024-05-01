import Config

config :distributed_simulator,
  max_iterations: 25,
  module_cell: Evacuation.Cell,
  module_metrics: Evacuation.Metrics,
  module_plan_creator: Evacuation.PlanCreator,
  module_plan_resolver: Evacuation.PlanResolver,
  signal_attenuation_factor: 0.65,
  signal_suppression_factor: 0.6

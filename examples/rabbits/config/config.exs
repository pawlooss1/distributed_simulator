import Config

config :nx, default_backend: EXLA.Backend
config :distributed_simulator,
  max_iterations: 150,
  module_cell: Rabbits.Cell,
  module_metrics: Rabbits.Metrics,
  module_plan_creator: Rabbits.PlanCreator,
  module_plan_resolver: Rabbits.PlanResolver,
  signal_attenuation_factor: 0.6,
  signal_suppression_factor: 0.6

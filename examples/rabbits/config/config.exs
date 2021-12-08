import Config

config :distributed_simulator,
  module_prefix: Rabbits,
  max_iterations: 25,
  signal_suppression_factor: 0.6,
  signal_attenuation_factor: 0.6

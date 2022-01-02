import Config

# if config_env() == :test do
  config :distributed_simulator,
    module_prefix: Test,
    max_iterations: 25,
    signal_suppression_factor: 0.8,
    signal_attenuation_factor: 0.4
# end

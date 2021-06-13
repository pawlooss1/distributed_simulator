import Config

config :distributed_simulator,
  x_size: 2,
  y_size: 2,
  mocks_by_dimension: 1,
  mode: String.to_atom(System.get_env("APP_MODE") || "nx")

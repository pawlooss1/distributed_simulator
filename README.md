# Distributed Simulator

Firstly, install dependencies:
```bash
mix deps.get
```

Then run:
```bash
mix run --no-halt run.exs
```

Optionally, you can provide environment variable `APP_MODE` to run specified implementation, e.g.:
```bash
APP_MODE=comparison mix run --no-halt run.exs
```
There are three modes: `nx`, `standard` and `comparison`. `nx` is default.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `distributed_simulator` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:distributed_simulator, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/distributed_simulator](https://hexdocs.pm/distributed_simulator).


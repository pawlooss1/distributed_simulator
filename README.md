# Distributed Simulator
Framework for creating generic distributed simulations.

It requires implementing a few callbacks to create a new simulation. 

There are two example simulations for reference:
- [Evacuation](https://github.com/sheldak/distributed_simulator/tree/master/examples/evacuation)
- [Rabbits and Lettuce](https://github.com/sheldak/distributed_simulator/tree/master/examples/rabbits)

## Installation
It requires Elixir 1.11 or newer and Erlang 22 or newer.

## Testing
Framework works only with some simulation. However, you can run tests.

Firstly, download dependencies:
```bash
mix deps.get
```

And then run the tests:
```bash
mix test
```
## Documentation
Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc).


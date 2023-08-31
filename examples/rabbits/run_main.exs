Process.sleep(1000)

[map_path | nodes] = System.argv()

nodes
|> Enum.map(fn host -> "node@" <> host end)
|> Enum.map(&String.to_atom/1)
|> Enum.each(fn node_name -> :pong = Node.ping(node_name) end)

:global.sync()

:ok = Rabbits.start(map_path)

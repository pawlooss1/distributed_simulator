Process.sleep(1000)

System.argv()
|> Enum.map(fn host -> "node@" <> host end)
|> Enum.map(&String.to_atom/1)
|> Enum.each(fn node_name -> :pong = Node.ping(node_name) end)

:ok = Evacuation.start()

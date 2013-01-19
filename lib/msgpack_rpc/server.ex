defmodule MessagePackRPC.Server do
  def start([name: name, transport: :tcp, handler: handler, options: options]) do
    :ranch.start_listener(name, 4, :ranch_tcp, options, MessagePackRPC.Protocol, [module: handler])
  end

  def stop(name: name) do
    :ranch.stop_listener(name)
  end
end

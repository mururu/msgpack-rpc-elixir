defmodule MessagePackRPC.Client do

  def connect(transport: transport, address: address, port: port) do
    connect(transport: transport, address: address, port: port, options: [])
  end

  def connect(transport: transport, address: address, port: port, options: options) do
    start_link(transport, address, port, options)
  end

  def close(pid) do
    :gen_server.call(pid, :close)
  end

  def call(pid: pid, func: method, args: args) do
    case call_async(pid: pid, func: method, args: args) do
      { :ok, call_id } ->
        join(pid: pid, req: call_id)
      error -> error
    end
  end

  def call_async(pid: pid, func: method, args: args) do
    bin_method = atom_to_binary(method, :latin1)
    :gen_server.call(pid, { :call_async, bin_method, args })
  end

  def join(pid: pid, req: call_id) do
    :gen_server.call(pid, { :join, call_id })
  end

  def notify(pid: pid, func: method, args: args) do
    bin_method = atom_to_binary(method, :latin1)
    :gen_server.cast(pid, { :notify, bin_method, args })
  end

  defp start_link(:tcp, address, port, options) do
    MessagePackRPC.Connection.start_link([transport: :ranch_tcp, address: address, port: port] ++ options)
  end
end

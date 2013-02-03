defmodule MessagePackRPC.Protocol do
  @behaviour :ranch_protocol
  use MessagePackRPC.Utils

  defrecord State, listener:         nil,
                   socket:           nil,
                   transport:        nil,
                   handler:          nil,
                   req_keepalive:    1,
                   max_keepalive:    nil,
                   max_line_length:  nil,
                   timeout:          nil,
                   buffer:           "",
                   hibernate:        false,
                   loop_timeout:     :infinity,
                   loop_timeout_ref: :undefined,
                   module:           :undefined

  def start_link(listener_pid, socket, transport, options) do
    pid = spawn_link(__MODULE__, :init, [listener_pid, socket, transport, options])
    { :ok, pid }
  end

  def init(listener_pid, socket, transport, options) do
    max_keepalive = options[:max_keepalive] || :infinity
    max_line_length = options[:max_line_length] || 4096
    timeout = options[:timeout] || 5000
    case options[:module] do
      nil ->
        { :error, :no_module_defined }
      module ->
        :ok = :ranch.accept_ack(listener_pid)
        :ok = transport.controlling_process(socket, self)

        wait_request(State[listener: listener_pid, socket: socket, transport: transport, max_keepalive: max_keepalive, max_line_length: max_line_length, timeout: timeout, module: module])
    end
  end

  def terminate(State[socket: socket, transport: transport]) do
    transport.close(socket)
  end

  defp wait_request(state = State[socket: socket, transport: transport, timeout: timeout, buffer: buffer]) do
    transport.setopts(socket, [{:active, :once}])
    receive do
      { :tcp, ^socket, data } ->
        state = state.buffer(<< buffer :: binary, data :: binary >>)
        parse_request(state)
      { :tcp_error, ^socket, _reason } ->
        terminate(state)
      { :tcp_closed, ^socket } ->
        terminate(state)
      { :reply, binary } ->
        :ok = transport.send(socket, binary)
        wait_request(state)
      _ ->
        wait_request(state)
    after
      timeout ->
        case byte_size(buffer) > 0 do
          true -> terminate(state)
          false -> wait_request(state)
        end
    end
  end

  defp parse_request(state = State[buffer: buffer, module: module]) do
    try do
      case MsgPack.unpack(buffer) do
        {[@mp_type_request, call_id, m, args], remain} ->
          spawn_request_handler(call_id, module, m, args)
          parse_request(state.update(buffer: remain))
        {[@mp_type_notify, m, args], remain} ->
          spawn_notify_handler(module, m, args)
          parse_request(state.update(buffer: remain))
        {:error, :incomplete} ->
          wait_request(state)
        {:error, reason} ->
          terminate(state)
      end
    rescue
      MsgPack.IncompletePacket ->
        wait_request(state)
      other ->
        IO.puts other.message
    end
  end

  defp spawn_notify_handler(module, m ,args) do
    spawn fn->
      method = :erlang.binary_to_existing_atom(m, :latin1)
      apply(module, method, args)
    end
  end

  defp spawn_request_handler(call_id, module, m, args) do
    pid = self
    spawn fn->
      method = binary_to_existing_atom(m, :latin1)
      prefix = [@mp_type_response, call_id]
      try do
        result = apply(module, method, args)
        pid <- { :reply, ((prefix ++ [nil, result]) |> MsgPack.pack |> MsgPack.packed_to_binary) }
      rescue
        x in [UndefinedFunctionError] ->
          pid <- { :reply, ((prefix ++ ["undef", nil]) |> MsgPack.pack |> MsgPack.packed_to_binary) }
      end
    end
  end
end

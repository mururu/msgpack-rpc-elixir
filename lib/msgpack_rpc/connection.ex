defmodule MessagePackRPC.Connection do
  @behaviour :gen_server
  use MessagePackRPC.Utils

  defrecord State, connection: nil, transport: nil, counter: 0, session: [], buffer: ""

  def start_link(args) do
    :gen_server.start_link(__MODULE__, args, [])
  end

  def init(args) do
    transport = args[:transport] || :ranch_rcp
    opts = case transport do
            :ranch_tcp -> [:binary, {:packet, :raw}, {:active, :once}]
           end
    address = args[:address] || :localhost
    port = args[:port] || 9199

    { :ok, socket } = transport.connect(address, port, opts)
    :ok = transport.controlling_process(socket, self)
    { :ok, State[connection: socket, transport: transport] }
  end


  def handle_call({:call_async, method, args}, _from, state = State[connection: socket, transport: transport, session: sessions, counter: count]) do
    call_id = count
    binary = [@mp_type_request, call_id, method, args] |> MsgPack.pack |> MsgPack.packed_to_binary
    :ok = transport.send(socket, binary)
    :ok = transport.setopts(socket, [{:active, :once}])
    { :reply, { :ok, call_id }, state.update(counter: count + 1, session: [{call_id, :none}|sessions]) }
  end

  def handle_call({:join, call_id}, from, state = State[session: sessions0]) do
    case :lists.keytake(call_id, 1, sessions0) do
      false ->
        { :reply, { :error, :norequest }, state }
      { :value, { ^call_id, :none }, sessions } ->
        { :noreply, state.update(session: [{call_id, {:waiting, from}}|sessions]) }
      { :value, { ^call_id, { :result, term } }, sessions } ->
        { :reply, term, state.update(sessions: sessions) }
      { :value, { ^call_id, { :waiting, ^from } }, _ } ->
        { :reply, { :error, :waiting }, state }
      { :value, { ^call_id, { :waiting, from1 } }, sessions } ->
        { :noreply, state.update(session: [{call_id, { :waiting, from1}}|sessions]) }
      _ ->
        { :noreply, state }
    end
  end

  def handle_call(:close, _from, state), do: { :stop, :normal, :ok, state }
  def handle_call(_request, _from, state), do: { :reply, { :error, :badevent }, state }


  def handle_cast({:notify, method, args}, state = State[connection: socket, transport: transport]) do
    binary = [@mp_type_notify, method, args] |> MsgPack.pack |> MsgPack.packed_to_binary
    :ok = transport.send(socket, binary)
    { :noreply, state }
  end

  def handle_cast(_msg, state) do
    { :noreply, state }
  end


  def handle_info({tcp, socket, bin}, state = State[transport: transport, session: sessions0, buffer: buf]) do
    if tcp == :tcp do
      new_buffer = << buf :: binary, bin :: binary >>
      :ok = transport.setopts(socket, [{:active, :once}])

      case MsgPack.unpack(new_buffer) do
        { :error, re } ->
          { :noreply, state.update(buffer: new_buffer) }
        { term, remain } ->
          [@mp_type_response, call_id, res_code, result] = term
          ret_val =
            case res_code do
              nil -> { :ok, result }
              error -> { :error, binary2known_error(error) }
            end

          case :lists.keytake(call_id, 1, sessions0) do
            false ->
              { :noreply, state }
            { :value, { ^call_id, :none }, sessions } ->
              { :noreply, state.update(session: [{call_id, {:result, ret_val}}|sessions], buffer: remain) }
            { :value, { ^call_id, { :waiting, from }}, sessions } ->
              :gen_server.reply(from, ret_val)
              { :noreply, state.update(session: sessions, buffer: remain) }
          end
      end
    end
  end

  def handle_info({:tcp_closed, _}, state) do
    { :noreply, state }
  end

  def handle_info(_info, state = State[connection: socket, transport: transport]) do
    :ok = transport.setopts(socket, [{:active, :once}])
    { :noreply, state }
  end

  def terminate(_reason, _state = State[connection: socket, transport: transport]) do
    transport.close(socket)
    :ok
  end

  def code_change(_old_vsn, state, _extra) do
    { :ok, state }
  end
end

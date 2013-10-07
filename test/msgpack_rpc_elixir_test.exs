Code.require_file "../test_helper.exs", __FILE__

defmodule MyHandler do
  def hello, do: "hello"
  def sum(x,y), do: x + y
end

defmodule MsgpackRPCTest do
  use ExUnit.Case

  # callbacks
  setup_all do
    :application.start(:ranch)
    MessagePackRPC.Server.start(name: :my_server, transport: :tcp, handler: MyHandler, options: [port: 9199])
    :ok
  end

  teardown_all do
    MessagePackRPC.Server.stop(name: :my_server)
    :application.stop(:ranch)
    :ok
  end

  setup do
    {:ok, pid} = MessagePackRPC.Client.connect(transport: :tcp, address: :localhost, port: 9199)
    Process.put(:client_pid, pid)
    :ok
  end

  teardown do
    :ok = MessagePackRPC.Client.close(client_pid)
    Process.delete(:client_pid)
    :ok
  end

  # util
  def client_pid do
    Process.get(:client_pid)
  end

  test "call" do
    assert MessagePackRPC.Client.call(pid: client_pid, func: :hello, args: []) == { :ok, "hello" }
    assert MessagePackRPC.Client.call(pid: client_pid, func: :sum, args: [1,2]) == { :ok, 3 }
  end

  test "notify" do
    assert MessagePackRPC.Client.notify(pid: client_pid, func: :hello, args: []) == :ok
    assert MessagePackRPC.Client.notify(pid: client_pid, func: :sum, args: [1,2]) == :ok
  end

  test "call_async" do
    {:ok, req1} = MessagePackRPC.Client.call_async(pid: client_pid, func: :hello, args: [])
    assert MessagePackRPC.Client.join(pid: client_pid, req: req1) == { :ok, "hello" }

    {:ok, req2} = MessagePackRPC.Client.call_async(pid: client_pid, func: :sum, args: [1,2])
    assert MessagePackRPC.Client.join(pid: client_pid, req: req2) == { :ok, 3 }
  end

  test "undef" do
    assert MessagePackRPC.Client.call(pid: client_pid, func: :hello, args: [1]) == { :error, :undef }
    assert MessagePackRPC.Client.call(pid: client_pid, func: :happy, args: []) == { :error, :undef }
  end
end

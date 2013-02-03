Code.require_file "../test_helper.exs", __FILE__

defmodule MyHandler do
  def hello, do: "hello"
  def sum(x,y), do: x + y
end

defmodule MsgpackRPCTest do
  use ExUnit.Case

  def setup_all do
    :application.start(:ranch)
    MessagePackRPC.Server.start(name: :my_server, transport: :tcp, handler: MyHandler, options: [port: 9199])
  end

  def teardown_all do
    MessagePackRPC.Server.stop(name: :my_server)
    :application.stop(:ranch)
  end

  test "call" do
    {:ok, pid} = MessagePackRPC.Client.connect(transport: :tcp, address: :localhost, port: 9199)

    assert MessagePackRPC.Client.call(pid: pid, func: :hello, args: []) == { :ok, "hello" }
    assert MessagePackRPC.Client.call(pid: pid, func: :sum, args: [1,2]) == { :ok, 3 }

    :ok = MessagePackRPC.Client.close(pid)
  end

  test "notify" do
    {:ok, pid} = MessagePackRPC.Client.connect(transport: :tcp, address: :localhost, port: 9199)

    assert MessagePackRPC.Client.notify(pid: pid, func: :hello, args: []) == :ok
    assert MessagePackRPC.Client.notify(pid: pid, func: :sum, args: [1,2]) == :ok

    :ok = MessagePackRPC.Client.close(pid)
  end

  test "call_async" do
    {:ok, pid} = MessagePackRPC.Client.connect(transport: :tcp, address: :localhost, port: 9199)

    {:ok, req1} = MessagePackRPC.Client.call_async(pid: pid, func: :hello, args: [])
    assert MessagePackRPC.Client.join(pid: pid, req: req1) == { :ok, "hello" }

    {:ok, req2} = MessagePackRPC.Client.call_async(pid: pid, func: :sum, args: [1,2])
    assert MessagePackRPC.Client.join(pid: pid, req: req2) == { :ok, 3 }

    :ok = MessagePackRPC.Client.close(pid)
  end

  test "undef" do
    {:ok, pid} = MessagePackRPC.Client.connect(transport: :tcp, address: :localhost, port: 9199)

    assert MessagePackRPC.Client.call(pid: pid, func: :hello, args: [1]) == { :error, :undef }
    assert MessagePackRPC.Client.call(pid: pid, func: :happy, args: []) == { :error, :undef }

    :ok = MessagePackRPC.Client.close(pid)
  end
end

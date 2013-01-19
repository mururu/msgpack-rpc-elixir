defmodule MsgpackRpcElixir.Mixfile do
  use Mix.Project

  def project do
    [ app: :msgpack_rpc_elixir,
      version: "0.0.1",
      deps: deps ]
  end

  # Configuration for the OTP application
  def application do
    []
  end

  # Returns the list of dependencies in the format:
  # { :foobar, "0.1", git: "https://github.com/elixir-lang/foobar.git" }
  defp deps do
    [{ :ranch, github: "extend/ranch"},
     { :exmsgpack, github: "yrashk/exmsgpack"}]
  end
end

defmodule MessagePackRPC.Utils do
  defmacro __using__(_) do
    quote do
      @mp_type_request 0
      @mp_type_response 1
      @mp_type_notify 2

      defp error2binary(:undef), do: "undef"

      defp binary2known_error("undef"), do: :undef
      defp binary2known_error(other), do: other
    end
  end
end

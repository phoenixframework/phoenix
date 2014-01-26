defmodule PlugHelper do

  defmacro __using__(_opts) do
    quote do
      use Plug.Test
      def simulate_request(router, http_method, path) do
        conn = conn(http_method, path)
        router.call(conn, [])
      end
    end
  end
end

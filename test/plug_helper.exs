defmodule PlugHelper do

  defmacro __using__(_opts) do
    quote do
      use Plug.Test
      import ExUnit.CaptureIO
      def simulate_request(router, http_method, path, params_or_body \\ nil, opts \\ []) do
        {conn, _} = capture_log fn ->
          conn = conn(http_method, path, params_or_body, opts)
          router.call(conn, [])
        end
        conn
      end

      def simulate_request_with_logging(router, http_method, path, params_or_body \\ nil, opts \\ []) do
        capture_log fn ->
          conn = conn(http_method, path, params_or_body, opts)
          router.call(conn, [])
        end
      end

      def capture_log(fun) do
        data = capture_io(:user, fn ->
          Process.put(:capture_log, fun.())
          Logger.flush()
        end) |> String.split("\n", trim: true)
        {Process.get(:capture_log), data}
      end
    end
  end
end

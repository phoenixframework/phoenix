defmodule Phoenix.Integration.CodeGeneration.MinimalAppTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  test "newly generated app has no warnings or errors" do
    with_installer_tmp("minimal_app", fn tmp_dir ->
      {app_root_path, _} =
        generate_phoenix_app(tmp_dir, "minimal", [
          "--no-html",
          "--no-assets",
          "--no-ecto",
          "--no-gettext",
          "--no-mailer",
          "--no-dashboard"
        ])

      assert_no_compilation_warnings(app_root_path)
      assert_passes_formatter_check(app_root_path)
      assert_tests_pass(app_root_path)
    end)
  end

  test "generated app boots with mix phx.server" do
    with_installer_tmp("development_workflow", fn tmp_dir ->
      {app_root_path, _} =
        generate_phoenix_app(tmp_dir, "minimal", [
          "--no-assets",
          "--no-ecto",
          "--no-gettext",
          "--no-mailer",
          "--no-dashboard"
        ])

      assert_no_compilation_warnings(app_root_path)

      with_phx_server(app_root_path, fn url ->
        {:ok, response} = http_get(url)
        assert response.status_code == 200
        assert response.body =~ "Minimal"
      end)
    end)
  end

  defp max_line_bytes, do: 4096

  defp with_phx_server(app_root_path, fun) do
    mix_bin = System.find_executable("mix") || raise "mix executable not found in PATH"

    port =
      Port.open(
        {:spawn_executable, mix_bin},
        [
          :binary,
          :exit_status,
          :stderr_to_stdout,
          line: max_line_bytes(),
          args: [
            "phx.server",
            "-e",
            "IO.puts(\"PHX_SERVER_READY\"); spawn(fn -> IO.gets([]); System.halt(0) end)"
          ],
          cd: app_root_path
        ]
      )

    try do
      await_server_ready(port)
      fun.("http://localhost:4000")
    after
      try do
        Port.command(port, "\n")
      rescue
        _ -> :ok
      end

      receive do
        {^port, {:exit_status, _}} -> :ok
      after
        5000 ->
          try do
            Port.close(port)
          rescue
            _ -> :ok
          end
      end

      flush_port(port)
    end
  end

  defp flush_port(port) do
    receive do
      {^port, _} -> flush_port(port)
    after
      0 -> :ok
    end
  end

  defp await_server_ready(port) do
    receive do
      {^port, {:data, {:eol, "PHX_SERVER_READY"}}} ->
        :ok

      {^port, {:data, _}} ->
        await_server_ready(port)

      {^port, {:exit_status, status}} ->
        flunk("Phoenix server exited prematurely with status #{inspect(status)}")
    after
      60_000 ->
        flunk("Timed out waiting for Phoenix server to start")
    end
  end

  defp http_get(url) do
    case url |> to_charlist() |> :httpc.request() do
      {:ok, {{_, status_code, _}, raw_headers, body}} ->
        {:ok,
         %{
           status_code: status_code,
           headers: for({k, v} <- raw_headers, do: {to_string(k), to_string(v)}),
           body: to_string(body)
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end
end

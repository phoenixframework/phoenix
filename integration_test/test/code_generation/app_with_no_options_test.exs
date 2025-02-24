defmodule Phoenix.Integration.CodeGeneration.AppWithNoOptionsTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  @epoch {{1970, 1, 1}, {0, 0, 0}}

  test "newly generated app has no warnings or errors" do
    with_installer_tmp("app_with_no_options", fn tmp_dir ->
      {app_root_path, _} =
        generate_phoenix_app(tmp_dir, "phx_blog", [
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

  test "development workflow works as expected" do
    with_installer_tmp("development_workflow", [autoremove?: false], fn tmp_dir ->
      {app_root_path, _} =
        generate_phoenix_app(tmp_dir, "phx_blog", [
          "--no-assets",
          "--no-ecto",
          "--no-gettext",
          "--no-mailer",
          "--no-dashboard"
        ])

      assert_no_compilation_warnings(app_root_path)

      File.touch!(Path.join(app_root_path, "lib/phx_blog_web/components/core_components.ex"), @epoch)
      File.touch!(Path.join(app_root_path, "lib/phx_blog_web/controllers/page_html.ex"), @epoch)

      spawn_link(fn ->
        run_phx_server(app_root_path)
      end)

      :inets.start()
      {:ok, response} = request_with_retries("http://localhost:4000", 20)
      assert response.status_code == 200
      assert response.body =~ "PhxBlog"

      assert File.stat!(Path.join(app_root_path, "lib/phx_blog_web/components/core_components.ex")) > @epoch
      assert File.stat!(Path.join(app_root_path, "lib/phx_blog_web/controllers/page_html.ex")) > @epoch
      assert_tests_pass(app_root_path)
    end)
  end

  defp run_phx_server(app_root_path) do
    {_output, 0} =
      System.cmd(
        "elixir",
        [
          "--no-halt",
          "-e",
          "spawn fn -> IO.gets([]) && System.halt(0) end",
          "-S",
          "mix",
          "phx.server"
        ],
        cd: app_root_path
      )
  end

  defp request_with_retries(url, retries)

  defp request_with_retries(_url, 0), do: {:error, :out_of_retries}

  defp request_with_retries(url, retries) do
    case url |> to_charlist() |> :httpc.request() do
      {:ok, httpc_response} ->
        {{_, status_code, _}, raw_headers, body} = httpc_response

        {:ok,
         %{
           status_code: status_code,
           headers: for({k, v} <- raw_headers, do: {to_string(k), to_string(v)}),
           body: to_string(body)
         }}

      {:error, {:failed_connect, _}} ->
        Process.sleep(5_000)
        request_with_retries(url, retries - 1)

      {:error, reason} ->
        {:error, reason}
    end
  end
end

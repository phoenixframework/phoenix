Code.require_file("../support/code_generator_case.exs", __DIR__)

defmodule Phoenix.Integration.CodeGeneration.AppWithNoOptionsTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  test "newly generated app has no warnings or errors" do
    with_installer_tmp("app_with_no_options", fn tmp_dir ->
      app_root_path = generate_phoenix_app(tmp_dir, "phx_blog", [
            "--no-html",
            "--no-webpack",
            "--no-ecto",
            "--no-gettext",
            "--no-dashboard"
          ])

      assert_no_compilation_warnings(app_root_path)
      assert_passes_formatter_check(app_root_path)
    end)
  end
end

defmodule Phoenix.Integration.CodeGeneration.AppWithDefaultsTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  test "newly generated app has no warnings or errors" do
    with_installer_tmp("new with defaults", fn tmp_dir ->
      app_root_path = generate_phoenix_app(tmp_dir, "phx_blog")

      assert_no_compilation_warnings(app_root_path)
      assert_passes_formatter_check(app_root_path)
    end)
  end
end

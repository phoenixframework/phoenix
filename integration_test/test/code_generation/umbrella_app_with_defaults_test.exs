defmodule Phoenix.Integration.CodeGeneration.UmbrellaAppWithDefaultsTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  test "new umbrella app" do
    with_installer_tmp("umbrella_app_with_defaults", fn tmp_dir ->
      app_root_path = generate_phoenix_app(tmp_dir, "phx_blog", ["--umbrella"])

      assert_no_compilation_warnings(app_root_path)
      assert_passes_formatter_check(app_root_path)
    end)
  end
end

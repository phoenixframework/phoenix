defmodule Phoenix.Template.TemplateTest do
  use ExUnit.Case, async: true
  alias Phoenix.Template

  test "#func_name_from_path/2 returns the function name from the full path" do
    file_path = "/var/www/templates/admin/users/show.html.eex"
    template_root = "/var/www/templates"
    assert Template.func_name_from_path(file_path, template_root) ==
      "admin/users/show.html"

    file_path = "/var/www/templates/users/show.html.eex"
    template_root = "/var/www/templates"
    assert Template.func_name_from_path(file_path, template_root) ==
      "users/show.html"

    file_path = "/var/www/templates/home.html.eex"
    template_root = "/var/www/templates"
    assert Template.func_name_from_path(file_path, template_root) ==
      "home.html"

    file_path = "/var/www/templates/home.html.haml"
    template_root = "/var/www/templates"
    assert Template.func_name_from_path(file_path, template_root) ==
      "home.html"
  end

  test "#find_all_from_root/1 returns wildcard of all contained templates" do
    root = Path.join([__DIR__], "../../fixtures/templates")
    templates = Template.find_all_from_root(root)
    assert File.exists?(templates |> Enum.at(0))
  end

  test "#eex_engine_for_file_ext/1 returns Phoenix.HTML.Engine for html extension" do
    assert Template.eex_engine_for_file_ext(".html") == Phoenix.HTML.Engine
  end

  test "#eex_engine_for_file_ext/1 returns EEx.SmartEngine for html extension" do
    assert Template.eex_engine_for_file_ext(".json") == EEx.SmartEngine
  end

  test "path_hash/1 returns the sha hash for dirctory list of file path" do
    assert Template.path_hash(Path.expand("test/fixtures/**/*"))
  end
end


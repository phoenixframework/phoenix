# Code.require_file "views.exs", __DIR__
#
# defmodule Phoenix.View.AutoCreatorTest do
#   use ExUnit.Case
#   alias Phoenix.View.AutoCreator
#   alias Phoenix.UserTest.Views
#
#   test "subview?/1 returns true when path is a directory and camelcased" do
#     assert AutoCreator.subview?(Path.join([__DIR__, "templates/layouts"]))
#   end
#
#   test "subview?/1 returns false when path is not a directory" do
#     refute AutoCreator.subview?(Path.join([__DIR__, "views/Layouts/application.html.eex"]))
#   end
#
#   test "subview?/1 returns false when directory is not camelcased" do
#     refute AutoCreator.subview?(Path.join([__DIR__, "templates/users/_nav"]))
#   end
#
#   test "subview_defined?/1 returns true when subview source file exists" do
#     assert AutoCreator.subview_defined?(Path.join([__DIR__, "templates/layouts"]))
#   end
#
#   test "subview_defined?/1 returns false when subview source file does not exist" do
#     refute AutoCreator.subview_defined?(Path.join([__DIR__, "templates/profiles"]))
#   end
#
#   test "implicit_subview_modules/2 returns implicit modules to be created" do
#     modules = AutoCreator.implicit_subview_modules(Views, Path.join([__DIR__, "templates"]))
#     assert modules == [
#       {Views.Profiles, Path.join([__DIR__, "templates/profiles"])}
#     ]
#   end
# end
#
#

defmodule Phoenix.Router.NamedRoutingTest do
  use ExUnit.Case, async: true
  use RouterHelper

  defmodule Router do
    use Phoenix.Router

    get "/users/:id", UserControler, :show, as: :profile
    get "/users/top", UserControler, :top, as: :top

    resources "/users", UserController do
      resources "/comments", CommentController do
        resources "/files", FileController
      end
    end

    resources "/files", FileController

    scope path: "/admin", alias: Admin do
      resources "/messages", MessageController
    end

    scope path: "/admin", alias: Admin, helper: "admin" do
      resources "/messages", MessageController
    end
  end

  alias Router.Helpers

  Application.put_env(:phoenix, Router,
    port: 1337, proxy_port: 80, host: "example.com", ssl: false)

  test "manual alias generated named route" do
    assert Router.profile_path(:show, 5, []) == "/users/5"
    assert Router.profile_path(:show, 5) == "/users/5"
    assert Router.top_path(:top, id: 5) == "/users/top?id=5"
  end

  test "resources generates named routes for :index, :edit, :show, :new" do
    assert Router.user_path(:index, []) == "/users"
    assert Router.user_path(:index) == "/users"
    assert Router.user_path(:edit, 123, []) == "/users/123/edit"
    assert Router.user_path(:edit, 123) == "/users/123/edit"
    assert Router.user_path(:show, 123, []) == "/users/123"
    assert Router.user_path(:show, 123) == "/users/123"
    assert Router.user_path(:new, []) == "/users/new"
    assert Router.user_path(:new) == "/users/new"
  end

  test "resources generates named routes for :create, :update, :delete" do
    assert Router.message_path(:create, []) == "/admin/messages"
    assert Router.message_path(:create) == "/admin/messages"

    assert Router.message_path(:update, 1, []) == "/admin/messages/1"
    assert Router.message_path(:update, 1) == "/admin/messages/1"

    assert Router.message_path(:destroy, 1, []) == "/admin/messages/1"
    assert Router.message_path(:destroy, 1) == "/admin/messages/1"
  end

  test "1-Level nested resources generates nested named routes for :index, :edit, :show, :new" do
    assert Router.user_comment_path(:index, 99, []) == "/users/99/comments"
    assert Router.user_comment_path(:index, 99) == "/users/99/comments"
    assert Router.user_comment_path(:edit, 88, 2, []) == "/users/88/comments/2/edit"
    assert Router.user_comment_path(:edit, 88, 2) == "/users/88/comments/2/edit"
    assert Router.user_comment_path(:show, 123, 2, []) == "/users/123/comments/2"
    assert Router.user_comment_path(:show, 123, 2) == "/users/123/comments/2"
    assert Router.user_comment_path(:new, 88, []) == "/users/88/comments/new"
    assert Router.user_comment_path(:new, 88) == "/users/88/comments/new"
  end

  test "2-Level nested resources generates nested named routes for :index, :edit, :show, :new" do
    assert Router.user_comment_file_path(:index, 99, 1, []) ==
      "/users/99/comments/1/files"
    assert Router.user_comment_file_path(:index, 99, 1) ==
      "/users/99/comments/1/files"

    assert Router.user_comment_file_path(:edit, 88, 1, 2, []) ==
      "/users/88/comments/1/files/2/edit"
    assert Router.user_comment_file_path(:edit, 88, 1, 2) ==
      "/users/88/comments/1/files/2/edit"

    assert Router.user_comment_file_path(:show, 123, 1, 2, []) ==
      "/users/123/comments/1/files/2"
    assert Router.user_comment_file_path(:show, 123, 1, 2) ==
      "/users/123/comments/1/files/2"

    assert Router.user_comment_file_path(:new, 88, 1, []) ==
      "/users/88/comments/1/files/new"
    assert Router.user_comment_file_path(:new, 88, 1) ==
      "/users/88/comments/1/files/new"
  end

  test "resources without block generates named routes for :index, :edit, :show, :new" do
    assert Router.file_path(:index, []) == "/files"
    assert Router.file_path(:index) == "/files"
    assert Router.file_path(:edit, 123, []) == "/files/123/edit"
    assert Router.file_path(:edit, 123) == "/files/123/edit"
    assert Router.file_path(:show, 123, []) == "/files/123"
    assert Router.file_path(:show, 123) == "/files/123"
    assert Router.file_path(:new, []) == "/files/new"
    assert Router.file_path(:new) == "/files/new"
  end

  test "scoped route helpers generated named routes with :path, and :alias options" do
    assert Router.message_path(:index, []) == "/admin/messages"
    assert Router.message_path(:index) == "/admin/messages"
    assert Router.message_path(:show, 1, []) == "/admin/messages/1"
    assert Router.message_path(:show, 1) == "/admin/messages/1"
  end

  test "scoped route helpers generated named routes with :path, :alias, and :helper options" do
    assert Router.admin_message_path(:index, []) == "/admin/messages"
    assert Router.admin_message_path(:index) == "/admin/messages"
    assert Router.admin_message_path(:show, 1, []) == "/admin/messages/1"
    assert Router.admin_message_path(:show, 1) == "/admin/messages/1"
  end

  test "helpers module is generated with named route helpers that can be imported" do
    assert Helpers.profile_path(:show, 5, []) == "/users/5"
    assert Helpers.profile_path(:show, 5) == "/users/5"
    assert Helpers.top_path(:top, id: 5) == "/users/top?id=5"
  end

  test "helpers module generates a url helper" do
    assert Helpers.url("/foo/bar") == "http://example.com/foo/bar"
  end
end


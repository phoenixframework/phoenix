defmodule Phoenix.Router.NamedRoutingTest do
  use ExUnit.Case, async: false
  use PlugHelper
  alias Phoenix.Router.NamedRoutingTest.Router

  setup_all do
    Mix.Config.persist(phoenix: [
      {Router, port: 1337, proxy_port: 80, host: "example.com", ssl: false}
    ])

    defmodule Router do
      use Phoenix.Router
      get "/users/:id", UsersController, :show, as: :profile
      get "/users/top", UsersController, :top, as: :top

      resources "users", UsersController do
        resources "comments", CommentsController do
          resources "files", FilesController
        end
      end
      resources "files", FilesController

      scope path: "admin", alias: Controllers.Admin do
        resources "messages", Messages
      end

      scope path: "admin", alias: Controllers.Admin, helper: "admin" do
        resources "messages", Messages
      end
    end

    :ok
  end

  test "manual alias generated named route" do
    assert Router.profile_path(:show, 5, []) == "/users/5"
    assert Router.profile_path(:show, 5) == "/users/5"
    assert Router.profile_url(:show, 5, []) == "http://example.com/users/5"
    assert Router.profile_url(:show, 5) == "http://example.com/users/5"
    assert Router.top_path(:top, id: 5) == "/users/top?id=5"
    assert Router.top_url(:top, id: 5) == "http://example.com/users/top?id=5"
  end

  test "resources generates named routes for :index, :edit, :show, :new" do
    assert Router.users_path(:index, []) == "/users"
    assert Router.users_path(:index) == "/users"
    assert Router.users_url(:index, []) == "http://example.com/users"
    assert Router.users_url(:index) == "http://example.com/users"
    assert Router.users_path(:edit, 123, []) == "/users/123/edit"
    assert Router.users_path(:edit, 123) == "/users/123/edit"
    assert Router.users_url(:edit, 123, []) == "http://example.com/users/123/edit"
    assert Router.users_url(:edit, 123) == "http://example.com/users/123/edit"
    assert Router.users_path(:show, 123, []) == "/users/123"
    assert Router.users_path(:show, 123) == "/users/123"
    assert Router.users_url(:show, 123, []) == "http://example.com/users/123"
    assert Router.users_url(:show, 123) == "http://example.com/users/123"
    assert Router.users_path(:new, []) == "/users/new"
    assert Router.users_path(:new) == "/users/new"
    assert Router.users_url(:new, []) == "http://example.com/users/new"
    assert Router.users_url(:new) == "http://example.com/users/new"
  end

  test "1-Level nested resources generates nested named routes for :index, :edit, :show, :new" do
    assert Router.users_comments_path(:index, 99, []) == "/users/99/comments"
    assert Router.users_comments_path(:index, 99) == "/users/99/comments"
    assert Router.users_comments_url(:index, 99, []) == "http://example.com/users/99/comments"
    assert Router.users_comments_url(:index, 99) == "http://example.com/users/99/comments"
    assert Router.users_comments_path(:edit, 88, 2, []) == "/users/88/comments/2/edit"
    assert Router.users_comments_path(:edit, 88, 2) == "/users/88/comments/2/edit"
    assert Router.users_comments_url(:edit, 88, 2, []) == "http://example.com/users/88/comments/2/edit"
    assert Router.users_comments_url(:edit, 88, 2) == "http://example.com/users/88/comments/2/edit"
    assert Router.users_comments_path(:show, 123, 2, []) == "/users/123/comments/2"
    assert Router.users_comments_path(:show, 123, 2) == "/users/123/comments/2"
    assert Router.users_comments_url(:show, 123, 2, []) == "http://example.com/users/123/comments/2"
    assert Router.users_comments_url(:show, 123, 2) == "http://example.com/users/123/comments/2"
    assert Router.users_comments_path(:new, 88, []) == "/users/88/comments/new"
    assert Router.users_comments_path(:new, 88) == "/users/88/comments/new"
    assert Router.users_comments_url(:new, 88, []) == "http://example.com/users/88/comments/new"
    assert Router.users_comments_url(:new, 88) == "http://example.com/users/88/comments/new"
  end

  test "2-Level nested resources generates nested named routes for :index, :edit, :show, :new" do
    assert Router.users_comments_files_path(:index, 99, 1, []) ==
      "/users/99/comments/1/files"
    assert Router.users_comments_files_path(:index, 99, 1) ==
      "/users/99/comments/1/files"

    assert Router.users_comments_files_url(:index, 99, 1, []) ==
      "http://example.com/users/99/comments/1/files"
    assert Router.users_comments_files_url(:index, 99, 1) ==
      "http://example.com/users/99/comments/1/files"


    assert Router.users_comments_files_path(:edit, 88, 1, 2, []) ==
      "/users/88/comments/1/files/2/edit"
    assert Router.users_comments_files_path(:edit, 88, 1, 2) ==
      "/users/88/comments/1/files/2/edit"

    assert Router.users_comments_files_url(:edit, 88, 1, 2, []) ==
      "http://example.com/users/88/comments/1/files/2/edit"
    assert Router.users_comments_files_url(:edit, 88, 1, 2) ==
      "http://example.com/users/88/comments/1/files/2/edit"


    assert Router.users_comments_files_path(:show, 123, 1, 2, []) ==
      "/users/123/comments/1/files/2"
    assert Router.users_comments_files_path(:show, 123, 1, 2) ==
      "/users/123/comments/1/files/2"

    assert Router.users_comments_files_url(:show, 123, 1, 2, []) ==
      "http://example.com/users/123/comments/1/files/2"
    assert Router.users_comments_files_url(:show, 123, 1, 2) ==
      "http://example.com/users/123/comments/1/files/2"


    assert Router.users_comments_files_path(:new, 88, 1, []) ==
      "/users/88/comments/1/files/new"
    assert Router.users_comments_files_path(:new, 88, 1) ==
      "/users/88/comments/1/files/new"

    assert Router.users_comments_files_url(:new, 88, 1, []) ==
      "http://example.com/users/88/comments/1/files/new"
    assert Router.users_comments_files_url(:new, 88, 1) ==
      "http://example.com/users/88/comments/1/files/new"

  end

  test "resources without block generates named routes for :index, :edit, :show, :new" do
    assert Router.files_path(:index, []) == "/files"
    assert Router.files_path(:index) == "/files"
    assert Router.files_url(:index, []) == "http://example.com/files"
    assert Router.files_url(:index) == "http://example.com/files"
    assert Router.files_path(:edit, 123, []) == "/files/123/edit"
    assert Router.files_path(:edit, 123) == "/files/123/edit"
    assert Router.files_url(:edit, 123, []) == "http://example.com/files/123/edit"
    assert Router.files_url(:edit, 123) == "http://example.com/files/123/edit"
    assert Router.files_path(:show, 123, []) == "/files/123"
    assert Router.files_path(:show, 123) == "/files/123"
    assert Router.files_url(:show, 123, []) == "http://example.com/files/123"
    assert Router.files_url(:show, 123) == "http://example.com/files/123"
    assert Router.files_path(:new, []) == "/files/new"
    assert Router.files_path(:new) == "/files/new"
    assert Router.files_url(:new, []) == "http://example.com/files/new"
    assert Router.files_url(:new) == "http://example.com/files/new"
  end

  test "scoped route helpers generated named routes with :path, and :alias options" do
    assert Router.messages_path(:index, []) == "/admin/messages"
    assert Router.messages_path(:index) == "/admin/messages"
    assert Router.messages_url(:index, []) == "http://example.com/admin/messages"
    assert Router.messages_url(:index) == "http://example.com/admin/messages"
    assert Router.messages_path(:show, 1, []) == "/admin/messages/1"
    assert Router.messages_path(:show, 1) == "/admin/messages/1"
    assert Router.messages_url(:show, 1, []) == "http://example.com/admin/messages/1"
    assert Router.messages_url(:show, 1) == "http://example.com/admin/messages/1"
  end

  test "scoped route helpers generated named routes with :path, :alias, and :helper options" do
    assert Router.admin_messages_path(:index, []) == "/admin/messages"
    assert Router.admin_messages_path(:index) == "/admin/messages"
    assert Router.admin_messages_url(:index, []) == "http://example.com/admin/messages"
    assert Router.admin_messages_url(:index) == "http://example.com/admin/messages"
    assert Router.admin_messages_path(:show, 1, []) == "/admin/messages/1"
    assert Router.admin_messages_path(:show, 1) == "/admin/messages/1"
    assert Router.admin_messages_url(:show, 1, []) == "http://example.com/admin/messages/1"
    assert Router.admin_messages_url(:show, 1) == "http://example.com/admin/messages/1"
  end
end


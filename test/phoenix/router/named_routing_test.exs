defmodule Phoenix.Router.NamedRoutingTest do
  use ExUnit.Case, async: false
  use PlugHelper
  alias Phoenix.Router.NamedRoutingTest.Router

  setup_all do
    Mix.Config.persist(phoenix: [
      routers: [
        [endpoint: Router, port: 80, host: "example.com", ssl: false]
      ]
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
    assert Router.profile_path(id: 5) == "/users/5"
    assert Router.profile_url(id: 5) == "http://example.com/users/5"
    assert Router.top_path(id: 5) == "/users/top?id=5"
    assert Router.top_url(id: 5) == "http://example.com/users/top?id=5"
  end

  test "resources generates named routes for :index, :edit, :show, :new" do
    assert Router.users_path == "/users"
    assert Router.users_url == "http://example.com/users"
    assert Router.edit_user_path(id: 123) == "/users/123/edit"
    assert Router.edit_user_url(id: 123) == "http://example.com/users/123/edit"
    assert Router.user_path(id: 123) == "/users/123"
    assert Router.user_url(id: 123) == "http://example.com/users/123"
    assert Router.new_user_path == "/users/new"
    assert Router.new_user_url == "http://example.com/users/new"
  end

  test "1-Level nested resources generates nested named routes for :index, :edit, :show, :new" do
    assert Router.user_comments_path(user_id: 99) == "/users/99/comments"
    assert Router.user_comments_url(user_id: 99) == "http://example.com/users/99/comments"
    assert Router.edit_user_comment_path(user_id: 88, id: 2) == "/users/88/comments/2/edit"
    assert Router.edit_user_comment_url(user_id: 88, id: 2) == "http://example.com/users/88/comments/2/edit"
    assert Router.user_comment_path(user_id: 123, id: 2) == "/users/123/comments/2"
    assert Router.user_comment_url(user_id: 123, id: 2) == "http://example.com/users/123/comments/2"
    assert Router.new_user_comment_path(user_id: 88) == "/users/88/comments/new"
    assert Router.new_user_comment_url(user_id: 88) == "http://example.com/users/88/comments/new"
  end

  test "2-Level nested resources generates nested named routes for :index, :edit, :show, :new" do
    assert Router.user_comment_files_path(user_id: 99, comment_id: 1) ==
      "/users/99/comments/1/files"
    assert Router.user_comment_files_url(user_id: 99, comment_id: 1) ==
      "http://example.com/users/99/comments/1/files"

    assert Router.edit_user_comment_file_path(user_id: 88, comment_id: 1, id: 2) ==
      "/users/88/comments/1/files/2/edit"
    assert Router.edit_user_comment_file_url(user_id: 88, comment_id: 1, id: 2) ==
      "http://example.com/users/88/comments/1/files/2/edit"

    assert Router.user_comment_file_path(user_id: 123, comment_id: 1, id: 2) ==
      "/users/123/comments/1/files/2"
    assert Router.user_comment_file_url(user_id: 123, comment_id: 1, id: 2) ==
      "http://example.com/users/123/comments/1/files/2"

    assert Router.new_user_comment_file_path(user_id: 88, comment_id: 1) ==
      "/users/88/comments/1/files/new"
    assert Router.new_user_comment_file_url(user_id: 88, comment_id: 1) ==
      "http://example.com/users/88/comments/1/files/new"
  end

  test "resources without block generates named routes for :index, :edit, :show, :new" do
    assert Router.files_path == "/files"
    assert Router.files_url == "http://example.com/files"
    assert Router.edit_file_path(id: 123) == "/files/123/edit"
    assert Router.edit_file_url(id: 123) == "http://example.com/files/123/edit"
    assert Router.file_path(id: 123) == "/files/123"
    assert Router.file_url(id: 123) == "http://example.com/files/123"
    assert Router.new_file_path == "/files/new"
    assert Router.new_file_url == "http://example.com/files/new"
  end

  test "scoped route helpers generated named routes with :path, and :alias options" do
    assert Router.messages_path == "/admin/messages"
    assert Router.messages_url == "http://example.com/admin/messages"
    assert Router.message_path(id: 1) == "/admin/messages/1"
    assert Router.message_url(id: 1) == "http://example.com/admin/messages/1"
  end

  test "scoped route helpers generated named routes with :path, :alias, and :helper options" do
    assert Router.admin_messages_path == "/admin/messages"
    assert Router.admin_messages_url == "http://example.com/admin/messages"
    assert Router.admin_message_path(id: 1) == "/admin/messages/1"
    assert Router.admin_message_url(id: 1) == "http://example.com/admin/messages/1"
  end
end


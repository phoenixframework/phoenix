defmodule Phoenix.Router.NamedRoutingTest do
  use ExUnit.Case
  use PlugHelper

  defmodule Router do
    use Phoenix.Router
    get "users/:id", UsersController, :show, as: :profile
    get "users/top", UsersController, :top, as: :top

    resources "users", UsersController do
      resources "comments", CommentsController do
        resources "files", FilesController
      end
    end
    resources "files", FilesController
  end

  test "manual alias generated named route" do
    assert Router.profile_path(id: 5) == "/users/5"
    assert Router.top_path(id: 5) == "/users/top"
  end

  test "resources generates named routes for :index, :edit, :show, :new" do
    assert Router.users_path == "/users"
    assert Router.edit_user_path(id: 123) == "/users/123/edit"
    assert Router.user_path(id: 123) == "/users/123"
    assert Router.new_user_path == "/users/new"
  end

  test "1-Level nested resources generates nested named routes for :index, :edit, :show, :new" do
    assert Router.user_comments_path(user_id: 99) == "/users/99/comments"
    assert Router.edit_user_comment_path(user_id: 88, id: 2) == "/users/88/comments/2/edit"
    assert Router.user_comment_path(user_id: 123, id: 2) == "/users/123/comments/2"
    assert Router.new_user_comment_path(user_id: 88) == "/users/88/comments/new"
  end

  test "2-Level nested resources generates nested named routes for :index, :edit, :show, :new" do
    assert Router.user_comment_files_path(user_id: 99, comment_id: 1) ==
      "/users/99/comments/1/files"

    assert Router.edit_user_comment_file_path(user_id: 88, comment_id: 1, id: 2) ==
      "/users/88/comments/1/files/2/edit"

    assert Router.user_comment_file_path(user_id: 123, comment_id: 1, id: 2) ==
      "/users/123/comments/1/files/2"

    assert Router.new_user_comment_file_path(user_id: 88, comment_id: 1) ==
      "/users/88/comments/1/files/new"
  end

  test "resources without block generates named routes for :index, :edit, :show, :new" do
    assert Router.files_path == "/files"
    assert Router.edit_file_path(id: 123) == "/files/123/edit"
    assert Router.file_path(id: 123) == "/files/123"
    assert Router.new_file_path == "/files/new"
  end
end


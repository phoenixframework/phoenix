defmodule Phoenix.Router.HelpersTest do
  use ExUnit.Case, async: true
  use RouterHelper

  alias Phoenix.Router.Helpers

  ## Unit tests

  test "defhelper with :identifiers" do
    route = build("GET", "/foo/:bar", nil, Hello, :world, "hello_world")

    assert extract_defhelper(route, 0) == String.strip """
    def(hello_world_path(conn_or_endpoint, :world, bar)) do
      hello_world_path(conn_or_endpoint, :world, bar, [])
    end
    """

    assert extract_defhelper(route, 1) == String.strip """
    def(hello_world_path(conn_or_endpoint, :world, bar, params)) do
      to_path(("" <> "/foo") <> "/" <> to_string(bar), params, ["bar"])
    end
    """
  end

  test "defhelper with *identifiers" do
    route = build("GET", "/foo/*bar", nil, Hello, :world, "hello_world")

    assert extract_defhelper(route, 0) == String.strip """
    def(hello_world_path(conn_or_endpoint, :world, bar)) do
      hello_world_path(conn_or_endpoint, :world, bar, [])
    end
    """

    assert extract_defhelper(route, 1) == String.strip """
    def(hello_world_path(conn_or_endpoint, :world, bar, params)) do
      to_path(("" <> "/foo") <> "/" <> Enum.join(bar, "/"), params, ["bar"])
    end
    """
  end

  defp build(verb, path, host, controller, action, helper) do
    Phoenix.Router.Route.build(verb, path, host, controller, action, helper, [], %{})
  end

  defp extract_defhelper(route, pos) do
    {:__block__, _, block} = Helpers.defhelper(route)
    Enum.at(block, pos) |> Macro.to_string()
  end

  ## Integration tests

  defmodule Router do
    use Phoenix.Router

    socket "/ws", as: :socket do
    end

    get "/posts/top", PostController, :top, as: :top
    get "/posts/:id", PostController, :show
    get "/posts/file/*file", PostController, :file
    get "/posts/skip", PostController, :skip, as: nil

    resources "/users", UserController do
      resources "/comments", CommentController do
        resources "/files", FileController
      end
    end

    resources "/files", FileController

    resource "/account", UserController, as: :account do
      resource "/page", PagesController, as: :page, only: [:show]
    end

    scope "/admin", alias: Admin do
      resources "/messages", MessageController
    end

    scope "/admin/new", alias: Admin, as: "admin" do
      resources "/messages", MessageController
    end

    get "/", PageController, :root, as: :page
  end

  alias Router.Helpers

  test "top-level named route" do
    assert Helpers.post_path(__MODULE__, :show, 5) == "/posts/5"
    assert Helpers.post_path(__MODULE__, :show, 5, []) == "/posts/5"
    assert Helpers.post_path(__MODULE__, :show, 5, id: 5) == "/posts/5"
    assert Helpers.post_path(__MODULE__, :show, 5, %{"id" => 5}) == "/posts/5"

    assert Helpers.post_path(__MODULE__, :file, ["foo", "bar"]) == "/posts/file/foo/bar"
    assert Helpers.post_path(__MODULE__, :file, ["foo", "bar"], []) == "/posts/file/foo/bar"

    assert Helpers.top_path(__MODULE__, :top) == "/posts/top"
    assert Helpers.top_path(__MODULE__, :top, id: 5) == "/posts/top?id=5"
    assert Helpers.top_path(__MODULE__, :top, %{"id" => 5}) == "/posts/top?id=5"

    assert Helpers.page_path(__MODULE__, :root) == "/"

    assert_raise UndefinedFunctionError, fn ->
      Helpers.post_path(__MODULE__, :skip)
    end
  end

  test "resources generates named routes for :index, :edit, :show, :new" do
    conn = conn(:get, "/") |> put_private(:phoenix_endpoint, __MODULE__)
    # Can pass either conn or __MODULE__ to named path helpers
    assert Helpers.user_path(conn, :index, []) == "/users"
    assert Helpers.user_path(__MODULE__, :index, []) == "/users"
    assert Helpers.user_path(__MODULE__, :index) == "/users"
    assert Helpers.user_path(__MODULE__, :edit, 123, []) == "/users/123/edit"
    assert Helpers.user_path(__MODULE__, :edit, 123) == "/users/123/edit"
    assert Helpers.user_path(__MODULE__, :show, 123, []) == "/users/123"
    assert Helpers.user_path(__MODULE__, :show, 123) == "/users/123"
    assert Helpers.user_path(__MODULE__, :new, []) == "/users/new"
    assert Helpers.user_path(__MODULE__, :new) == "/users/new"
  end

  test "resources generates named routes for :create, :update, :delete" do
    assert Helpers.message_path(__MODULE__, :create, []) == "/admin/messages"
    assert Helpers.message_path(__MODULE__, :create) == "/admin/messages"

    assert Helpers.message_path(__MODULE__, :update, 1, []) == "/admin/messages/1"
    assert Helpers.message_path(__MODULE__, :update, 1) == "/admin/messages/1"

    assert Helpers.message_path(__MODULE__, :delete, 1, []) == "/admin/messages/1"
    assert Helpers.message_path(__MODULE__, :delete, 1) == "/admin/messages/1"
  end

  test "1-Level nested resources generates nested named routes for :index, :edit, :show, :new" do
    assert Helpers.user_comment_path(__MODULE__, :index, 99, []) == "/users/99/comments"
    assert Helpers.user_comment_path(__MODULE__, :index, 99) == "/users/99/comments"
    assert Helpers.user_comment_path(__MODULE__, :edit, 88, 2, []) == "/users/88/comments/2/edit"
    assert Helpers.user_comment_path(__MODULE__, :edit, 88, 2) == "/users/88/comments/2/edit"
    assert Helpers.user_comment_path(__MODULE__, :show, 123, 2, []) == "/users/123/comments/2"
    assert Helpers.user_comment_path(__MODULE__, :show, 123, 2) == "/users/123/comments/2"
    assert Helpers.user_comment_path(__MODULE__, :new, 88, []) == "/users/88/comments/new"
    assert Helpers.user_comment_path(__MODULE__, :new, 88) == "/users/88/comments/new"
  end

  test "2-Level nested resources generates nested named routes for :index, :edit, :show, :new" do
    assert Helpers.user_comment_file_path(__MODULE__, :index, 99, 1, []) ==
      "/users/99/comments/1/files"
    assert Helpers.user_comment_file_path(__MODULE__, :index, 99, 1) ==
      "/users/99/comments/1/files"

    assert Helpers.user_comment_file_path(__MODULE__, :edit, 88, 1, 2, []) ==
      "/users/88/comments/1/files/2/edit"
    assert Helpers.user_comment_file_path(__MODULE__, :edit, 88, 1, 2) ==
      "/users/88/comments/1/files/2/edit"

    assert Helpers.user_comment_file_path(__MODULE__, :show, 123, 1, 2, []) ==
      "/users/123/comments/1/files/2"
    assert Helpers.user_comment_file_path(__MODULE__, :show, 123, 1, 2) ==
      "/users/123/comments/1/files/2"

    assert Helpers.user_comment_file_path(__MODULE__, :new, 88, 1, []) ==
      "/users/88/comments/1/files/new"
    assert Helpers.user_comment_file_path(__MODULE__, :new, 88, 1) ==
      "/users/88/comments/1/files/new"
  end

  test "resources without block generates named routes for :index, :edit, :show, :new" do
    assert Helpers.file_path(__MODULE__, :index, []) == "/files"
    assert Helpers.file_path(__MODULE__, :index) == "/files"
    assert Helpers.file_path(__MODULE__, :edit, 123, []) == "/files/123/edit"
    assert Helpers.file_path(__MODULE__, :edit, 123) == "/files/123/edit"
    assert Helpers.file_path(__MODULE__, :show, 123, []) == "/files/123"
    assert Helpers.file_path(__MODULE__, :show, 123) == "/files/123"
    assert Helpers.file_path(__MODULE__, :new, []) == "/files/new"
    assert Helpers.file_path(__MODULE__, :new) == "/files/new"
  end

  test "resource generates named routes for :show, :edit, :new, :update, :delete" do
    assert Helpers.account_path(__MODULE__, :show, []) == "/account"
    assert Helpers.account_path(__MODULE__, :show) == "/account"
    assert Helpers.account_path(__MODULE__, :edit, []) == "/account/edit"
    assert Helpers.account_path(__MODULE__, :edit) == "/account/edit"
    assert Helpers.account_path(__MODULE__, :new, []) == "/account/new"
    assert Helpers.account_path(__MODULE__, :new) == "/account/new"
    assert Helpers.account_path(__MODULE__, :update, []) == "/account"
    assert Helpers.account_path(__MODULE__, :update) == "/account"
    assert Helpers.account_path(__MODULE__, :delete, []) == "/account"
    assert Helpers.account_path(__MODULE__, :delete) == "/account"
  end

  test "2-Level nested resource generates nested named routes for :show" do
    assert Helpers.account_page_path(__MODULE__, :show, []) == "/account/page"
    assert Helpers.account_page_path(__MODULE__, :show) == "/account/page"
  end

  test "scoped route helpers generated named routes with :path, and :alias options" do
    assert Helpers.message_path(__MODULE__, :index, []) == "/admin/messages"
    assert Helpers.message_path(__MODULE__, :index) == "/admin/messages"
    assert Helpers.message_path(__MODULE__, :show, 1, []) == "/admin/messages/1"
    assert Helpers.message_path(__MODULE__, :show, 1) == "/admin/messages/1"
  end

  test "scoped route helpers generated named routes with :path, :alias, and :helper options" do
    assert Helpers.admin_message_path(__MODULE__, :index, []) == "/admin/new/messages"
    assert Helpers.admin_message_path(__MODULE__, :index) == "/admin/new/messages"
    assert Helpers.admin_message_path(__MODULE__, :show, 1, []) == "/admin/new/messages/1"
    assert Helpers.admin_message_path(__MODULE__, :show, 1) == "/admin/new/messages/1"
  end

  def url(path) do
    "https://example.com" <> path
  end

  def static_path(path) do
    path
  end

  test "helpers module generates named routes url helpers" do
    conn = conn(:get, "/") |> put_private(:phoenix_endpoint, __MODULE__)
    url = "https://example.com/admin/new/messages/1"
    assert Helpers.admin_message_url(conn, :show, 1) == url
    assert Helpers.admin_message_url(conn, :show, 1, []) == url
    assert Helpers.admin_message_url(__MODULE__, :show, 1) == url
    assert Helpers.admin_message_url(__MODULE__, :show, 1, []) == url
  end

  test "helpers module generates a url helper" do
    conn = conn(:get, "/") |> put_private(:phoenix_endpoint, __MODULE__)
    assert Helpers.url(conn, "/foo/bar") == "https://example.com/foo/bar"
    assert Helpers.url(__MODULE__, "/foo/bar") == "https://example.com/foo/bar"
  end

  test "helpers module generates a static_path helper" do
    conn = conn(:get, "/") |> put_private(:phoenix_endpoint, __MODULE__)
    assert Helpers.static_path(conn, "/images/foo.png") == "/images/foo.png"
    assert Helpers.static_path(__MODULE__, "/images/foo.png") == "/images/foo.png"
  end

  test "helpers module generates a static_url helper" do
    conn = conn(:get, "/") |> put_private(:phoenix_endpoint, __MODULE__)
    url = "https://example.com/images/foo.png"
    assert Helpers.static_url(conn, "/images/foo.png") == url
    assert Helpers.static_url(__MODULE__, "/images/foo.png") == url
  end

  test "socket defines helper with `:as` option" do
    conn = conn(:get, "/") |> put_private(:phoenix_endpoint, __MODULE__)
    assert Helpers.socket_path(conn, :upgrade) == "/ws"
    assert Helpers.socket_path(__MODULE__, :upgrade) == "/ws"
    url = "https://example.com/ws"
    assert Helpers.socket_url(conn, :upgrade) == url
    assert Helpers.socket_url(__MODULE__, :upgrade) == url
  end
end

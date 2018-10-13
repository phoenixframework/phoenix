defmodule Phoenix.Router.RoutesTest do
  use ExUnit.Case, async: true
  use RouterHelper

  alias Phoenix.Router.Routes

  ## Unit tests

  test "defhelper with :identifiers" do
    route = build(:match, :get, "/foo/:bar", nil, Hello, :world, "hello_world")
    assert extract_defhelper(route, 0) == String.trim """
    def(hello_world_path(conn_or_endpoint, :world, bar)) do
      hello_world_path(conn_or_endpoint, :world, bar, [])
    end
    """

    assert extract_defhelper(route, 1) == String.trim """
    def(hello_world_path(conn_or_endpoint, :world, bar, params) when is_list(params) or is_map(params)) do
      path(conn_or_endpoint, segments(("" <> "/foo") <> "/" <> URI.encode(to_param(bar), &URI.char_unreserved?/1), params, ["bar"], {"hello_world", :world, ["bar"]}))
    end
    """
  end

  test "defhelper with *identifiers" do
    route = build(:match, :get, "/foo/*bar", nil, Hello, :world, "hello_world")

    assert extract_defhelper(route, 0) == String.trim """
    def(hello_world_path(conn_or_endpoint, :world, bar)) do
      hello_world_path(conn_or_endpoint, :world, bar, [])
    end
    """

    assert extract_defhelper(route, 1) == String.trim """
    def(hello_world_path(conn_or_endpoint, :world, bar, params) when is_list(params) or is_map(params)) do
      path(conn_or_endpoint, segments(("" <> "/foo") <> "/" <> Enum.map_join(bar, "/", fn s -> URI.encode(s, &URI.char_unreserved?/1) end), params, ["bar"], {"hello_world", :world, ["bar"]}))
    end
    """
  end

  defp build(kind, verb, path, host, controller, action, helper) do
    Phoenix.Router.Route.build(1, kind, verb, path, host, controller, action, helper, [], %{}, %{})
  end

  defp extract_defhelper(route, pos) do
    {:__block__, _, block} = Routes.defhelper(route, Phoenix.Router.Route.exprs(route))
    Enum.fetch!(block, pos) |> Macro.to_string()
  end

  ## Integration tests

  defmodule Router do
    use Phoenix.Router

    get "/posts/top", PostController, :top, as: :top
    get "/posts/bottom/:order/:count", PostController, :bottom, as: :bottom
    get "/posts/:id", PostController, :show
    get "/posts/file/*file", PostController, :file
    get "/posts/skip", PostController, :skip, as: nil

    get "/chat*js_route", ChatController, :show

    resources "/users", UserController do
      resources "/comments", CommentController do
        resources "/files", FileController
      end
    end

    resources "/files", FileController

    resources "/account", UserController, as: :account, singleton: true do
      resources "/page", PagesController, as: :page, only: [:show], singleton: true
    end

    scope "/admin", alias: Admin do
      resources "/messages", MessageController
    end

    scope "/admin/new", alias: Admin, as: "admin" do
      resources "/messages", MessageController
    end

    get "/", PageController, :root, as: :page
    get "/products/:id", ProductController, :show
    get "/products/:id/:sort", ProductController, :show
    get "/products/:id/:sort/:page", ProductController, :show
  end

  # Emulate regular endpoint functions

  def url do
    "https://example.com"
  end

  def static_url do
    "https://static.example.com"
  end

  def path(path) do
    path
  end

  def static_path(path) do
    path
  end

  alias Router.Routes

  test "defines a __helpers__ function" do
    assert Router.__helpers__ == Router.Routes
  end

  test "root helper" do
    conn = conn(:get, "/") |> put_private(:phoenix_endpoint, __MODULE__)
    assert Routes.page_path(conn, :root) == "/"
    assert Routes.page_path(__MODULE__, :root) == "/"
  end

  test "url helper with query strings" do
    assert Routes.post_path(__MODULE__, :show, 5, id: 3) == "/posts/5"
    assert Routes.post_path(__MODULE__, :show, 5, foo: "bar") == "/posts/5?foo=bar"
    assert Routes.post_path(__MODULE__, :show, 5, foo: :bar) == "/posts/5?foo=bar"
    assert Routes.post_path(__MODULE__, :show, 5, foo: true) == "/posts/5?foo=true"
    assert Routes.post_path(__MODULE__, :show, 5, foo: false) == "/posts/5?foo=false"
    assert Routes.post_path(__MODULE__, :show, 5, foo: nil) == "/posts/5?foo="

    assert Routes.post_path(__MODULE__, :show, 5, foo: ~w(bar baz)) ==
           "/posts/5?foo[]=bar&foo[]=baz"
    assert Routes.post_path(__MODULE__, :show, 5, foo: %{id: 5}) ==
           "/posts/5?foo[id]=5"
    assert Routes.post_path(__MODULE__, :show, 5, foo: %{__struct__: Foo, id: 5}) ==
           "/posts/5?foo=5"
  end

  test "url helper with param protocol" do
    assert Routes.post_path(__MODULE__, :show, %{__struct__: Foo, id: 5}) == "/posts/5"

    assert_raise ArgumentError, fn ->
      Routes.post_path(__MODULE__, :show, nil)
    end
  end

  test "url helper shows an error if an id is accidentally passed" do
    error_suggestion = ~r/bottom_path\(conn, :bottom, order, count, page: 5, per_page: 10\)/

    assert_raise ArgumentError, error_suggestion, fn ->
      Routes.bottom_path(__MODULE__, :bottom, :asc, 8, {:not, :enumerable})
    end

    error_suggestion = ~r/top_path\(conn, :top, page: 5, per_page: 10\)/

    assert_raise ArgumentError, error_suggestion, fn ->
      Routes.top_path(__MODULE__, :top, "invalid")
    end
  end

  test "top-level named route" do
    assert Routes.post_path(__MODULE__, :show, 5) == "/posts/5"
    assert Routes.post_path(__MODULE__, :show, 5, []) == "/posts/5"
    assert Routes.post_path(__MODULE__, :show, 5, id: 5) == "/posts/5"
    assert Routes.post_path(__MODULE__, :show, 5, %{"id" => 5}) == "/posts/5"
    assert Routes.post_path(__MODULE__, :show, "foo") == "/posts/foo"
    assert Routes.post_path(__MODULE__, :show, "foo bar") == "/posts/foo%20bar"

    assert Routes.post_path(__MODULE__, :file, ["foo", "bar/baz"]) == "/posts/file/foo/bar%2Fbaz"
    assert Routes.post_path(__MODULE__, :file, ["foo", "bar"], []) == "/posts/file/foo/bar"
    assert Routes.post_path(__MODULE__, :file, ["foo", "bar baz"], []) == "/posts/file/foo/bar%20baz"

    assert Routes.chat_path(__MODULE__, :show, ["chat"]) == "/chat"
    assert Routes.chat_path(__MODULE__, :show, ["chat", "foo"]) == "/chat/foo"
    assert Routes.chat_path(__MODULE__, :show, ["chat/foo"]) == "/chat%2Ffoo"
    assert Routes.chat_path(__MODULE__, :show, ["chat/foo", "bar/baz"]) == "/chat%2Ffoo/bar%2Fbaz"

    assert Routes.top_path(__MODULE__, :top) == "/posts/top"
    assert Routes.top_path(__MODULE__, :top, id: 5) == "/posts/top?id=5"
    assert Routes.top_path(__MODULE__, :top, %{"id" => 5}) == "/posts/top?id=5"
    assert Routes.top_path(__MODULE__, :top, %{"id" => "foo"}) == "/posts/top?id=foo"
    assert Routes.top_path(__MODULE__, :top, %{"id" => "foo bar"}) == "/posts/top?id=foo+bar"

    error_message = fn helper, arity ->
      """
      no function clause for #{inspect Routes}.#{helper}/#{arity} and action :skip. The following actions/clauses are supported:

          #{helper}(conn_or_endpoint, :file, file, params \\\\ [])
          #{helper}(conn_or_endpoint, :show, id, params \\\\ [])

      """ |> String.trim
    end

    assert_raise UndefinedFunctionError, fn ->
      Routes.post_path(__MODULE__, :skip)
    end

    assert_raise UndefinedFunctionError, fn ->
      Routes.post_url(__MODULE__, :skip)
    end

    assert_raise ArgumentError, error_message.("post_path", 3), fn ->
      Routes.post_path(__MODULE__, :skip, 5)
    end

    assert_raise ArgumentError, error_message.("post_url", 3), fn ->
      Routes.post_url(__MODULE__, :skip, 5)
    end

    assert_raise ArgumentError, error_message.("post_path", 4), fn ->
      Routes.post_path(__MODULE__, :skip, 5, foo: "bar", other: "param")
    end

    assert_raise ArgumentError, error_message.("post_url", 4), fn ->
      Routes.post_url(__MODULE__, :skip, 5, foo: "bar", other: "param")
    end

    assert_raise ArgumentError, ~r/when building url for Phoenix.Router.RoutesTest.Router/, fn ->
      Routes.post_url("oops", :skip, 5, foo: "bar", other: "param")
    end

    assert_raise ArgumentError, ~r/when building path for Phoenix.Router.RoutesTest.Router/, fn ->
      Routes.post_path("oops", :skip, 5, foo: "bar", other: "param")
    end
  end

  test "top-level named routes with complex ids" do
    assert Routes.post_path(__MODULE__, :show, "==d--+") ==
      "/posts/%3D%3Dd--%2B"
    assert Routes.post_path(__MODULE__, :show, "==d--+", []) ==
      "/posts/%3D%3Dd--%2B"
    assert Routes.top_path(__MODULE__, :top, id: "==d--+") ==
      "/posts/top?id=%3D%3Dd--%2B"

    assert Routes.post_path(__MODULE__, :file, ["==d--+", ":O.jpg"]) ==
      "/posts/file/%3D%3Dd--%2B/%3AO.jpg"
    assert Routes.post_path(__MODULE__, :file, ["==d--+", ":O.jpg"], []) ==
      "/posts/file/%3D%3Dd--%2B/%3AO.jpg"
    assert Routes.post_path(__MODULE__, :file, ["==d--+", ":O.jpg"], xx: "/=+/") ==
      "/posts/file/%3D%3Dd--%2B/%3AO.jpg?xx=%2F%3D%2B%2F"
  end

  test "resources generates named routes for :index, :edit, :show, :new" do
    assert Routes.user_path(__MODULE__, :index, []) == "/users"
    assert Routes.user_path(__MODULE__, :index) == "/users"
    assert Routes.user_path(__MODULE__, :edit, 123, []) == "/users/123/edit"
    assert Routes.user_path(__MODULE__, :edit, 123) == "/users/123/edit"
    assert Routes.user_path(__MODULE__, :show, 123, []) == "/users/123"
    assert Routes.user_path(__MODULE__, :show, 123) == "/users/123"
    assert Routes.user_path(__MODULE__, :new, []) == "/users/new"
    assert Routes.user_path(__MODULE__, :new) == "/users/new"
  end

  test "resources generated named routes with complex ids" do
    assert Routes.user_path(__MODULE__, :edit, "1a+/31d", []) == "/users/1a%2B%2F31d/edit"
    assert Routes.user_path(__MODULE__, :edit, "1a+/31d") == "/users/1a%2B%2F31d/edit"
    assert Routes.user_path(__MODULE__, :show, "1a+/31d", []) == "/users/1a%2B%2F31d"
    assert Routes.user_path(__MODULE__, :show, "1a+/31d") == "/users/1a%2B%2F31d"

    assert Routes.message_path(__MODULE__, :update, "8=/=d", []) == "/admin/messages/8%3D%2F%3Dd"
    assert Routes.message_path(__MODULE__, :update, "8=/=d") == "/admin/messages/8%3D%2F%3Dd"
    assert Routes.message_path(__MODULE__, :delete, "8=/=d", []) == "/admin/messages/8%3D%2F%3Dd"
    assert Routes.message_path(__MODULE__, :delete, "8=/=d") == "/admin/messages/8%3D%2F%3Dd"

    assert Routes.user_path(__MODULE__, :show, "1a+/31d", [dog: "8d="]) == "/users/1a%2B%2F31d?dog=8d%3D"
    assert Routes.user_path(__MODULE__, :index, [cat: "=8+/&"]) == "/users?cat=%3D8%2B%2F%26"
  end

  test "resources generates named routes for :create, :update, :delete" do
    assert Routes.message_path(__MODULE__, :create, []) == "/admin/messages"
    assert Routes.message_path(__MODULE__, :create) == "/admin/messages"

    assert Routes.message_path(__MODULE__, :update, 1, []) == "/admin/messages/1"
    assert Routes.message_path(__MODULE__, :update, 1) == "/admin/messages/1"

    assert Routes.message_path(__MODULE__, :delete, 1, []) == "/admin/messages/1"
    assert Routes.message_path(__MODULE__, :delete, 1) == "/admin/messages/1"
  end

  test "1-Level nested resources generates nested named routes for :index, :edit, :show, :new" do
    assert Routes.user_comment_path(__MODULE__, :index, 99, []) == "/users/99/comments"
    assert Routes.user_comment_path(__MODULE__, :index, 99) == "/users/99/comments"
    assert Routes.user_comment_path(__MODULE__, :edit, 88, 2, []) == "/users/88/comments/2/edit"
    assert Routes.user_comment_path(__MODULE__, :edit, 88, 2) == "/users/88/comments/2/edit"
    assert Routes.user_comment_path(__MODULE__, :show, 123, 2, []) == "/users/123/comments/2"
    assert Routes.user_comment_path(__MODULE__, :show, 123, 2) == "/users/123/comments/2"
    assert Routes.user_comment_path(__MODULE__, :new, 88, []) == "/users/88/comments/new"
    assert Routes.user_comment_path(__MODULE__, :new, 88) == "/users/88/comments/new"

    error_message = fn helper, arity ->
      """
      no function clause for #{inspect Routes}.#{helper}/#{arity} and action :skip. The following actions/clauses are supported:

          user_comment_file_path(conn_or_endpoint, :create, user_id, comment_id, params \\\\ [])
          user_comment_file_path(conn_or_endpoint, :delete, user_id, comment_id, id, params \\\\ [])
          user_comment_file_path(conn_or_endpoint, :edit, user_id, comment_id, id, params \\\\ [])
          user_comment_file_path(conn_or_endpoint, :index, user_id, comment_id, params \\\\ [])
          user_comment_file_path(conn_or_endpoint, :new, user_id, comment_id, params \\\\ [])
          user_comment_file_path(conn_or_endpoint, :show, user_id, comment_id, id, params \\\\ [])
          user_comment_file_path(conn_or_endpoint, :update, user_id, comment_id, id, params \\\\ [])
      """ |> String.trim
    end

    assert_raise ArgumentError, error_message.("user_comment_file_path", 4), fn ->
      Routes.user_comment_file_path(__MODULE__, :skip, 123, 456)
    end

    assert_raise ArgumentError, error_message.("user_comment_file_path", 5), fn ->
      Routes.user_comment_file_path(__MODULE__, :skip, 123, 456, foo: "bar")
    end

    arity_error_message =
      """
      no action :show for helper #{inspect Routes}.user_comment_path/3. The following actions/clauses are supported:

          user_comment_path(conn_or_endpoint, :create, user_id, params \\\\ [])
          user_comment_path(conn_or_endpoint, :delete, user_id, id, params \\\\ [])
          user_comment_path(conn_or_endpoint, :edit, user_id, id, params \\\\ [])
          user_comment_path(conn_or_endpoint, :index, user_id, params \\\\ [])
          user_comment_path(conn_or_endpoint, :new, user_id, params \\\\ [])
          user_comment_path(conn_or_endpoint, :show, user_id, id, params \\\\ [])
          user_comment_path(conn_or_endpoint, :update, user_id, id, params \\\\ [])

      """ |> String.trim

    assert_raise ArgumentError, arity_error_message, fn ->
      Routes.user_comment_path(__MODULE__, :show, 123)
    end
  end

  test "multi-level nested resources generated named routes with complex ids" do
    assert Routes.user_comment_path(__MODULE__, :index, "f4/d+~=", []) ==
      "/users/f4%2Fd%2B~%3D/comments"
    assert Routes.user_comment_path(__MODULE__, :index, "f4/d+~=") ==
      "/users/f4%2Fd%2B~%3D/comments"
    assert Routes.user_comment_path(__MODULE__, :edit, "f4/d+~=", "x-+=/", []) ==
      "/users/f4%2Fd%2B~%3D/comments/x-%2B%3D%2F/edit"
    assert Routes.user_comment_path(__MODULE__, :edit, "f4/d+~=", "x-+=/") ==
      "/users/f4%2Fd%2B~%3D/comments/x-%2B%3D%2F/edit"
    assert Routes.user_comment_path(__MODULE__, :show, "f4/d+~=", "x-+=/", []) ==
      "/users/f4%2Fd%2B~%3D/comments/x-%2B%3D%2F"
    assert Routes.user_comment_path(__MODULE__, :show, "f4/d+~=", "x-+=/") ==
      "/users/f4%2Fd%2B~%3D/comments/x-%2B%3D%2F"
    assert Routes.user_comment_path(__MODULE__, :new, "/==/", []) ==
      "/users/%2F%3D%3D%2F/comments/new"
    assert Routes.user_comment_path(__MODULE__, :new, "/==/") ==
      "/users/%2F%3D%3D%2F/comments/new"

    assert Routes.user_comment_file_path(__MODULE__, :show, "f4/d+~=", "/==/", "x-+=/", []) ==
      "/users/f4%2Fd%2B~%3D/comments/%2F%3D%3D%2F/files/x-%2B%3D%2F"
    assert Routes.user_comment_file_path(__MODULE__, :show, "f4/d+~=", "/==/", "x-+=/") ==
      "/users/f4%2Fd%2B~%3D/comments/%2F%3D%3D%2F/files/x-%2B%3D%2F"
  end

  test "2-Level nested resources generates nested named routes for :index, :edit, :show, :new" do
    assert Routes.user_comment_file_path(__MODULE__, :index, 99, 1, []) ==
      "/users/99/comments/1/files"
    assert Routes.user_comment_file_path(__MODULE__, :index, 99, 1) ==
      "/users/99/comments/1/files"

    assert Routes.user_comment_file_path(__MODULE__, :edit, 88, 1, 2, []) ==
      "/users/88/comments/1/files/2/edit"
    assert Routes.user_comment_file_path(__MODULE__, :edit, 88, 1, 2) ==
      "/users/88/comments/1/files/2/edit"

    assert Routes.user_comment_file_path(__MODULE__, :show, 123, 1, 2, []) ==
      "/users/123/comments/1/files/2"
    assert Routes.user_comment_file_path(__MODULE__, :show, 123, 1, 2) ==
      "/users/123/comments/1/files/2"

    assert Routes.user_comment_file_path(__MODULE__, :new, 88, 1, []) ==
      "/users/88/comments/1/files/new"
    assert Routes.user_comment_file_path(__MODULE__, :new, 88, 1) ==
      "/users/88/comments/1/files/new"
  end

  test "resources without block generates named routes for :index, :edit, :show, :new" do
    assert Routes.file_path(__MODULE__, :index, []) == "/files"
    assert Routes.file_path(__MODULE__, :index) == "/files"
    assert Routes.file_path(__MODULE__, :edit, 123, []) == "/files/123/edit"
    assert Routes.file_path(__MODULE__, :edit, 123) == "/files/123/edit"
    assert Routes.file_path(__MODULE__, :show, 123, []) == "/files/123"
    assert Routes.file_path(__MODULE__, :show, 123) == "/files/123"
    assert Routes.file_path(__MODULE__, :new, []) == "/files/new"
    assert Routes.file_path(__MODULE__, :new) == "/files/new"
  end

  test "resource generates named routes for :show, :edit, :new, :update, :delete" do
    assert Routes.account_path(__MODULE__, :show, []) == "/account"
    assert Routes.account_path(__MODULE__, :show) == "/account"
    assert Routes.account_path(__MODULE__, :edit, []) == "/account/edit"
    assert Routes.account_path(__MODULE__, :edit) == "/account/edit"
    assert Routes.account_path(__MODULE__, :new, []) == "/account/new"
    assert Routes.account_path(__MODULE__, :new) == "/account/new"
    assert Routes.account_path(__MODULE__, :update, []) == "/account"
    assert Routes.account_path(__MODULE__, :update) == "/account"
    assert Routes.account_path(__MODULE__, :delete, []) == "/account"
    assert Routes.account_path(__MODULE__, :delete) == "/account"
  end

  test "2-Level nested resource generates nested named routes for :show" do
    assert Routes.account_page_path(__MODULE__, :show, []) == "/account/page"
    assert Routes.account_page_path(__MODULE__, :show) == "/account/page"
  end

  test "scoped route helpers generated named routes with :path, and :alias options" do
    assert Routes.message_path(__MODULE__, :index, []) == "/admin/messages"
    assert Routes.message_path(__MODULE__, :index) == "/admin/messages"
    assert Routes.message_path(__MODULE__, :show, 1, []) == "/admin/messages/1"
    assert Routes.message_path(__MODULE__, :show, 1) == "/admin/messages/1"
  end

  test "scoped route helpers generated named routes with :path, :alias, and :helper options" do
    assert Routes.admin_message_path(__MODULE__, :index, []) == "/admin/new/messages"
    assert Routes.admin_message_path(__MODULE__, :index) == "/admin/new/messages"
    assert Routes.admin_message_path(__MODULE__, :show, 1, []) == "/admin/new/messages/1"
    assert Routes.admin_message_path(__MODULE__, :show, 1) == "/admin/new/messages/1"
  end

  ## Others

  defp conn_with_endpoint do
    conn(:get, "/") |> put_private(:phoenix_endpoint, __MODULE__)
  end

  defp socket_with_endpoint do
    %Phoenix.Socket{endpoint: __MODULE__}
  end

  defp uri do
    %URI{scheme: "https", host: "example.com", port: 443}
  end

  test "routes module generates a static_path helper" do
    assert Routes.static_path(__MODULE__, "/images/foo.png") == "/images/foo.png"
    assert Routes.static_path(conn_with_endpoint(), "/images/foo.png") == "/images/foo.png"
    assert Routes.static_path(socket_with_endpoint(), "/images/foo.png") == "/images/foo.png"
  end

  test "routes module generates a static_url helper" do
    url = "https://static.example.com/images/foo.png"
    assert Routes.static_url(__MODULE__, "/images/foo.png") == url
    assert Routes.static_url(conn_with_endpoint(), "/images/foo.png") == url
    assert Routes.static_url(socket_with_endpoint(), "/images/foo.png") == url
  end

  test "routes module generates a url helper" do
    assert Routes.url(__MODULE__) == "https://example.com"
    assert Routes.url(conn_with_endpoint()) == "https://example.com"
    assert Routes.url(socket_with_endpoint()) == "https://example.com"
    assert Routes.url(uri()) == "https://example.com"
  end

  test "phoenix_router_url with string takes precedence over endpoint" do
    url = "https://phoenixframework.org"
    conn = Phoenix.Controller.put_router_url(conn_with_endpoint(), url)

    assert Routes.url(conn) == url
    assert Routes.admin_message_url(conn, :show, 1) ==
      url <> "/admin/new/messages/1"
  end

  test "phoenix_router_url with URI takes precedence over endpoint" do
    uri = %URI{scheme: "https", host: "phoenixframework.org", port: 123, path: "/path"}
    conn = Phoenix.Controller.put_router_url(conn_with_endpoint(), uri)

    assert Routes.url(conn) == "https://phoenixframework.org:123"
    assert Routes.admin_message_url(conn, :show, 1) ==
      "https://phoenixframework.org:123/admin/new/messages/1"
  end

  test "routes module generates a path helper" do
    assert Routes.path(__MODULE__, "/") == "/"
    assert Routes.path(conn_with_endpoint(), "/") == "/"
    assert Routes.path(socket_with_endpoint(), "/") == "/"
    assert Routes.path(uri(), "/") == "/"
  end

  test "routes module generates named routes url helpers" do
    url = "https://example.com/admin/new/messages/1"
    assert Routes.admin_message_url(__MODULE__, :show, 1) == url
    assert Routes.admin_message_url(__MODULE__, :show, 1, []) == url
    assert Routes.admin_message_url(conn_with_endpoint(), :show, 1) == url
    assert Routes.admin_message_url(conn_with_endpoint(), :show, 1, []) == url
    assert Routes.admin_message_url(socket_with_endpoint(), :show, 1) == url
    assert Routes.admin_message_url(socket_with_endpoint(), :show, 1, []) == url
    assert Routes.admin_message_url(uri(), :show, 1) == url
    assert Routes.admin_message_url(uri(), :show, 1, []) == url
  end

  ## Script name

  defmodule ScriptName do
    def url do
      "https://example.com"
    end

    def static_url do
      "https://static.example.com"
    end

    def path(path) do
      "/api" <> path
    end

    def static_path(path) do
      "/api" <> path
    end
  end

  def conn_with_script_name(script_name \\ ~w(api)) do
    conn = conn(:get, "/")
           |> put_private(:phoenix_endpoint, ScriptName)
    put_in conn.script_name, script_name
  end

  defp uri_with_script_name do
    %URI{scheme: "https", host: "example.com", port: 123, path: "/api"}
  end

  test "paths use script name" do
    assert Routes.page_path(ScriptName, :root) == "/api/"
    assert Routes.page_path(conn_with_script_name(), :root) == "/api/"
    assert Routes.page_path(uri_with_script_name(), :root) == "/api/"
    assert Routes.post_path(ScriptName, :show, 5) == "/api/posts/5"
    assert Routes.post_path(conn_with_script_name(), :show, 5) == "/api/posts/5"
    assert Routes.post_path(uri_with_script_name(), :show, 5) == "/api/posts/5"
  end

  test "urls use script name" do
    assert Routes.page_url(ScriptName, :root) ==
           "https://example.com/api/"
    assert Routes.page_url(conn_with_script_name(), :root) ==
           "https://example.com/api/"
    assert Routes.page_url(uri_with_script_name(), :root) ==
           "https://example.com:123/api/"

    assert Routes.post_url(ScriptName, :show, 5) ==
           "https://example.com/api/posts/5"
    assert Routes.post_url(conn_with_script_name(), :show, 5) ==
           "https://example.com/api/posts/5"
    assert Routes.post_url(uri_with_script_name(), :show, 5) ==
           "https://example.com:123/api/posts/5"
  end

  test "static does not use script name" do
    assert Routes.static_path(conn_with_script_name(~w(foo)), "/images/foo.png") ==
           "/api/images/foo.png"

    assert Routes.static_url(conn_with_script_name(~w(foo)), "/images/foo.png") ==
           "https://static.example.com/api/images/foo.png"
  end

  test "helpers properly encode named and query string params" do
    assert Router.Routes.post_path(__MODULE__, :show, "my path", foo: "my param") ==
      "/posts/my%20path?foo=my+param"
  end

  test "duplicate helpers with unique arities" do
    assert Routes.product_path(__MODULE__, :show, 123) == "/products/123"
    assert Routes.product_path(__MODULE__, :show, 123, foo: "bar") == "/products/123?foo=bar"
    assert Routes.product_path(__MODULE__, :show, 123, "asc") == "/products/123/asc"
    assert Routes.product_path(__MODULE__, :show, 123, "asc", foo: "bar") == "/products/123/asc?foo=bar"
    assert Routes.product_path(__MODULE__, :show, 123, "asc", 1) == "/products/123/asc/1"
    assert Routes.product_path(__MODULE__, :show, 123, "asc", 1, foo: "bar") == "/products/123/asc/1?foo=bar"
  end
end

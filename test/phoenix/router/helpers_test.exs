defmodule Phoenix.Router.HelpersTest do
  use ExUnit.Case, async: true
  use RouterHelper

  alias Phoenix.Router.Helpers

  ## Unit tests

  test "defhelper with :identifiers" do
    route = build(:match, :get, "/foo/:bar", nil, Hello, :world, "hello_world")

    assert extract_defhelper(route, 0) == String.trim """
    def(hello_world_path(conn_or_endpoint, :world, bar)) do
      hello_world_path(conn_or_endpoint, :world, bar, [])
    end
    """

    assert extract_defhelper(route, 1) == String.trim """
    def(hello_world_path(conn_or_endpoint, :world, bar, params)) do
      path(conn_or_endpoint, segments(("" <> "/foo") <> "/" <> URI.encode(to_param(bar), &URI.char_unreserved?/1), params, ["bar"]))
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
    def(hello_world_path(conn_or_endpoint, :world, bar, params)) do
      path(conn_or_endpoint, segments(("" <> "/foo") <> "/" <> Enum.map_join(bar, "/", fn s -> URI.encode(s, &URI.char_unreserved?/1) end), params, ["bar"]))
    end
    """
  end

  defp build(kind, verb, path, host, controller, action, helper) do
    Phoenix.Router.Route.build(1, kind, verb, path, host, controller, action, helper, [], %{}, %{})
  end

  defp extract_defhelper(route, pos) do
    {:__block__, _, block} = Helpers.defhelper(route, Phoenix.Router.Route.exprs(route))
    Enum.fetch!(block, pos) |> Macro.to_string()
  end

  ## Integration tests

  defmodule Router do
    use Phoenix.Router

    get "/posts/top", PostController, :top, as: :top
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

  alias Router.Helpers

  test "defines a __helpers__ function" do
    assert Router.__helpers__ == Router.Helpers
  end

  test "root helper" do
    conn = conn(:get, "/") |> put_private(:phoenix_endpoint, __MODULE__)
    assert Helpers.page_path(conn, :root) == "/"
    assert Helpers.page_path(__MODULE__, :root) == "/"
  end

  test "url helper with query strings" do
    assert Helpers.post_path(__MODULE__, :show, 5, id: 3) == "/posts/5"
    assert Helpers.post_path(__MODULE__, :show, 5, foo: "bar") == "/posts/5?foo=bar"
    assert Helpers.post_path(__MODULE__, :show, 5, foo: :bar) == "/posts/5?foo=bar"
    assert Helpers.post_path(__MODULE__, :show, 5, foo: true) == "/posts/5?foo=true"
    assert Helpers.post_path(__MODULE__, :show, 5, foo: false) == "/posts/5?foo=false"
    assert Helpers.post_path(__MODULE__, :show, 5, foo: nil) == "/posts/5?foo="

    assert Helpers.post_path(__MODULE__, :show, 5, foo: ~w(bar baz)) ==
           "/posts/5?foo[]=bar&foo[]=baz"
    assert Helpers.post_path(__MODULE__, :show, 5, foo: %{id: 5}) ==
           "/posts/5?foo[id]=5"
    assert Helpers.post_path(__MODULE__, :show, 5, foo: %{__struct__: Foo, id: 5}) ==
           "/posts/5?foo=5"
  end

  test "url helper with param protocol" do
    assert Helpers.post_path(__MODULE__, :show, %{__struct__: Foo, id: 5}) == "/posts/5"

    assert_raise ArgumentError, fn ->
      Helpers.post_path(__MODULE__, :show, nil)
    end
  end

  test "top-level named route" do
    assert Helpers.post_path(__MODULE__, :show, 5) == "/posts/5"
    assert Helpers.post_path(__MODULE__, :show, 5, []) == "/posts/5"
    assert Helpers.post_path(__MODULE__, :show, 5, id: 5) == "/posts/5"
    assert Helpers.post_path(__MODULE__, :show, 5, %{"id" => 5}) == "/posts/5"
    assert Helpers.post_path(__MODULE__, :show, "foo") == "/posts/foo"
    assert Helpers.post_path(__MODULE__, :show, "foo bar") == "/posts/foo%20bar"

    assert Helpers.post_path(__MODULE__, :file, ["foo", "bar/baz"]) == "/posts/file/foo/bar%2Fbaz"
    assert Helpers.post_path(__MODULE__, :file, ["foo", "bar"], []) == "/posts/file/foo/bar"
    assert Helpers.post_path(__MODULE__, :file, ["foo", "bar baz"], []) == "/posts/file/foo/bar%20baz"

    assert Helpers.chat_path(__MODULE__, :show, ["chat"]) == "/chat"
    assert Helpers.chat_path(__MODULE__, :show, ["chat", "foo"]) == "/chat/foo"
    assert Helpers.chat_path(__MODULE__, :show, ["chat/foo"]) == "/chat%2Ffoo"
    assert Helpers.chat_path(__MODULE__, :show, ["chat/foo", "bar/baz"]) == "/chat%2Ffoo/bar%2Fbaz"

    assert Helpers.top_path(__MODULE__, :top) == "/posts/top"
    assert Helpers.top_path(__MODULE__, :top, id: 5) == "/posts/top?id=5"
    assert Helpers.top_path(__MODULE__, :top, %{"id" => 5}) == "/posts/top?id=5"
    assert Helpers.top_path(__MODULE__, :top, %{"id" => "foo"}) == "/posts/top?id=foo"
    assert Helpers.top_path(__MODULE__, :top, %{"id" => "foo bar"}) == "/posts/top?id=foo+bar"

    error_message = fn helper, arity ->
      """
      No function clause for #{inspect Helpers}.#{helper}/#{arity} and action :skip. The following actions/clauses are supported:

          #{helper}(conn_or_endpoint, :file, file, opts \\\\ [])
          #{helper}(conn_or_endpoint, :show, id, opts \\\\ [])

      """ |> String.trim
    end

    assert_raise UndefinedFunctionError, fn ->
      Helpers.post_path(__MODULE__, :skip)
    end

    assert_raise UndefinedFunctionError, fn ->
      Helpers.post_url(__MODULE__, :skip)
    end

    assert_raise ArgumentError, error_message.("post_path", 3), fn ->
      Helpers.post_path(__MODULE__, :skip, 5)
    end

    assert_raise ArgumentError, error_message.("post_url", 3), fn ->
      Helpers.post_url(__MODULE__, :skip, 5)
    end

    assert_raise ArgumentError, error_message.("post_path", 4), fn ->
      Helpers.post_path(__MODULE__, :skip, 5, foo: "bar", other: "param")
    end

    assert_raise ArgumentError, error_message.("post_url", 4), fn ->
      Helpers.post_url(__MODULE__, :skip, 5, foo: "bar", other: "param")
    end

    assert_raise ArgumentError, ~r/when building url for Phoenix.Router.HelpersTest.Router/, fn ->
      Helpers.post_url("oops", :skip, 5, foo: "bar", other: "param")
    end

    assert_raise ArgumentError, ~r/when building path for Phoenix.Router.HelpersTest.Router/, fn ->
      Helpers.post_path("oops", :skip, 5, foo: "bar", other: "param")
    end
  end

  test "top-level named routes with complex ids" do
    assert Helpers.post_path(__MODULE__, :show, "==d--+") ==
      "/posts/%3D%3Dd--%2B"
    assert Helpers.post_path(__MODULE__, :show, "==d--+", []) ==
      "/posts/%3D%3Dd--%2B"
    assert Helpers.top_path(__MODULE__, :top, id: "==d--+") ==
      "/posts/top?id=%3D%3Dd--%2B"

    assert Helpers.post_path(__MODULE__, :file, ["==d--+", ":O.jpg"]) ==
      "/posts/file/%3D%3Dd--%2B/%3AO.jpg"
    assert Helpers.post_path(__MODULE__, :file, ["==d--+", ":O.jpg"], []) ==
      "/posts/file/%3D%3Dd--%2B/%3AO.jpg"
    assert Helpers.post_path(__MODULE__, :file, ["==d--+", ":O.jpg"], xx: "/=+/") ==
      "/posts/file/%3D%3Dd--%2B/%3AO.jpg?xx=%2F%3D%2B%2F"
  end

  test "resources generates named routes for :index, :edit, :show, :new" do
    assert Helpers.user_path(__MODULE__, :index, []) == "/users"
    assert Helpers.user_path(__MODULE__, :index) == "/users"
    assert Helpers.user_path(__MODULE__, :edit, 123, []) == "/users/123/edit"
    assert Helpers.user_path(__MODULE__, :edit, 123) == "/users/123/edit"
    assert Helpers.user_path(__MODULE__, :show, 123, []) == "/users/123"
    assert Helpers.user_path(__MODULE__, :show, 123) == "/users/123"
    assert Helpers.user_path(__MODULE__, :new, []) == "/users/new"
    assert Helpers.user_path(__MODULE__, :new) == "/users/new"
  end

  test "resources generated named routes with complex ids" do
    assert Helpers.user_path(__MODULE__, :edit, "1a+/31d", []) == "/users/1a%2B%2F31d/edit"
    assert Helpers.user_path(__MODULE__, :edit, "1a+/31d") == "/users/1a%2B%2F31d/edit"
    assert Helpers.user_path(__MODULE__, :show, "1a+/31d", []) == "/users/1a%2B%2F31d"
    assert Helpers.user_path(__MODULE__, :show, "1a+/31d") == "/users/1a%2B%2F31d"

    assert Helpers.message_path(__MODULE__, :update, "8=/=d", []) == "/admin/messages/8%3D%2F%3Dd"
    assert Helpers.message_path(__MODULE__, :update, "8=/=d") == "/admin/messages/8%3D%2F%3Dd"
    assert Helpers.message_path(__MODULE__, :delete, "8=/=d", []) == "/admin/messages/8%3D%2F%3Dd"
    assert Helpers.message_path(__MODULE__, :delete, "8=/=d") == "/admin/messages/8%3D%2F%3Dd"

    assert Helpers.user_path(__MODULE__, :show, "1a+/31d", [dog: "8d="]) == "/users/1a%2B%2F31d?dog=8d%3D"
    assert Helpers.user_path(__MODULE__, :index, [cat: "=8+/&"]) == "/users?cat=%3D8%2B%2F%26"
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

    error_message = fn helper, arity ->
      """
      No function clause for #{inspect Helpers}.#{helper}/#{arity} and action :skip. The following actions/clauses are supported:

          user_comment_file_path(conn_or_endpoint, :create, user_id, comment_id, opts \\\\ [])
          user_comment_file_path(conn_or_endpoint, :delete, user_id, comment_id, id, opts \\\\ [])
          user_comment_file_path(conn_or_endpoint, :edit, user_id, comment_id, id, opts \\\\ [])
          user_comment_file_path(conn_or_endpoint, :index, user_id, comment_id, opts \\\\ [])
          user_comment_file_path(conn_or_endpoint, :new, user_id, comment_id, opts \\\\ [])
          user_comment_file_path(conn_or_endpoint, :show, user_id, comment_id, id, opts \\\\ [])
          user_comment_file_path(conn_or_endpoint, :update, user_id, comment_id, id, opts \\\\ [])
      """ |> String.trim
    end

    assert_raise ArgumentError, error_message.("user_comment_file_path", 4), fn ->
      Helpers.user_comment_file_path(__MODULE__, :skip, 123, 456)
    end

    assert_raise ArgumentError, error_message.("user_comment_file_path", 5), fn ->
      Helpers.user_comment_file_path(__MODULE__, :skip, 123, 456, foo: "bar")
    end

    arity_error_message =
      """
      No action :show for helper #{inspect Helpers}.user_comment_path/3. The following actions/clauses are supported:

          user_comment_path(conn_or_endpoint, :create, user_id, opts \\\\ [])
          user_comment_path(conn_or_endpoint, :delete, user_id, id, opts \\\\ [])
          user_comment_path(conn_or_endpoint, :edit, user_id, id, opts \\\\ [])
          user_comment_path(conn_or_endpoint, :index, user_id, opts \\\\ [])
          user_comment_path(conn_or_endpoint, :new, user_id, opts \\\\ [])
          user_comment_path(conn_or_endpoint, :show, user_id, id, opts \\\\ [])
          user_comment_path(conn_or_endpoint, :update, user_id, id, opts \\\\ [])

      """ |> String.trim

    assert_raise ArgumentError, arity_error_message, fn ->
      Helpers.user_comment_path(__MODULE__, :show, 123)
    end
  end

  test "multi-level nested resources generated named routes with complex ids" do
    assert Helpers.user_comment_path(__MODULE__, :index, "f4/d+~=", []) ==
      "/users/f4%2Fd%2B~%3D/comments"
    assert Helpers.user_comment_path(__MODULE__, :index, "f4/d+~=") ==
      "/users/f4%2Fd%2B~%3D/comments"
    assert Helpers.user_comment_path(__MODULE__, :edit, "f4/d+~=", "x-+=/", []) ==
      "/users/f4%2Fd%2B~%3D/comments/x-%2B%3D%2F/edit"
    assert Helpers.user_comment_path(__MODULE__, :edit, "f4/d+~=", "x-+=/") ==
      "/users/f4%2Fd%2B~%3D/comments/x-%2B%3D%2F/edit"
    assert Helpers.user_comment_path(__MODULE__, :show, "f4/d+~=", "x-+=/", []) ==
      "/users/f4%2Fd%2B~%3D/comments/x-%2B%3D%2F"
    assert Helpers.user_comment_path(__MODULE__, :show, "f4/d+~=", "x-+=/") ==
      "/users/f4%2Fd%2B~%3D/comments/x-%2B%3D%2F"
    assert Helpers.user_comment_path(__MODULE__, :new, "/==/", []) ==
      "/users/%2F%3D%3D%2F/comments/new"
    assert Helpers.user_comment_path(__MODULE__, :new, "/==/") ==
      "/users/%2F%3D%3D%2F/comments/new"

    assert Helpers.user_comment_file_path(__MODULE__, :show, "f4/d+~=", "/==/", "x-+=/", []) ==
      "/users/f4%2Fd%2B~%3D/comments/%2F%3D%3D%2F/files/x-%2B%3D%2F"
    assert Helpers.user_comment_file_path(__MODULE__, :show, "f4/d+~=", "/==/", "x-+=/") ==
      "/users/f4%2Fd%2B~%3D/comments/%2F%3D%3D%2F/files/x-%2B%3D%2F"
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

  test "helpers module generates a static_path helper" do
    assert Helpers.static_path(__MODULE__, "/images/foo.png") == "/images/foo.png"
    assert Helpers.static_path(conn_with_endpoint(), "/images/foo.png") == "/images/foo.png"
    assert Helpers.static_path(socket_with_endpoint(), "/images/foo.png") == "/images/foo.png"
  end

  test "helpers module generates a static_url helper" do
    url = "https://static.example.com/images/foo.png"
    assert Helpers.static_url(__MODULE__, "/images/foo.png") == url
    assert Helpers.static_url(conn_with_endpoint(), "/images/foo.png") == url
    assert Helpers.static_url(socket_with_endpoint(), "/images/foo.png") == url
  end

  test "helpers module generates a url helper" do
    assert Helpers.url(__MODULE__) == "https://example.com"
    assert Helpers.url(conn_with_endpoint()) == "https://example.com"
    assert Helpers.url(socket_with_endpoint()) == "https://example.com"
    assert Helpers.url(uri()) == "https://example.com"
  end

  test "phoenix_router_url with string takes precedence over endpoint" do
    url = "https://phoenixframework.org"
    conn = Phoenix.Controller.put_router_url(conn_with_endpoint(), url)

    assert Helpers.url(conn) == url
    assert Helpers.admin_message_url(conn, :show, 1) ==
      url <> "/admin/new/messages/1"
  end

  test "phoenix_router_url with URI takes precedence over endpoint" do
    uri = %URI{scheme: "https", host: "phoenixframework.org", port: 123, path: "/path"}
    conn = Phoenix.Controller.put_router_url(conn_with_endpoint(), uri)

    assert Helpers.url(conn) == "https://phoenixframework.org:123"
    assert Helpers.admin_message_url(conn, :show, 1) ==
      "https://phoenixframework.org:123/admin/new/messages/1"
  end

  test "helpers module generates a path helper" do
    assert Helpers.path(__MODULE__, "/") == "/"
    assert Helpers.path(conn_with_endpoint(), "/") == "/"
    assert Helpers.path(socket_with_endpoint(), "/") == "/"
    assert Helpers.path(uri(), "/") == "/"
  end

  test "helpers module generates named routes url helpers" do
    url = "https://example.com/admin/new/messages/1"
    assert Helpers.admin_message_url(__MODULE__, :show, 1) == url
    assert Helpers.admin_message_url(__MODULE__, :show, 1, []) == url
    assert Helpers.admin_message_url(conn_with_endpoint(), :show, 1) == url
    assert Helpers.admin_message_url(conn_with_endpoint(), :show, 1, []) == url
    assert Helpers.admin_message_url(socket_with_endpoint(), :show, 1) == url
    assert Helpers.admin_message_url(socket_with_endpoint(), :show, 1, []) == url
    assert Helpers.admin_message_url(uri(), :show, 1) == url
    assert Helpers.admin_message_url(uri(), :show, 1, []) == url
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
    assert Helpers.page_path(ScriptName, :root) == "/api/"
    assert Helpers.page_path(conn_with_script_name(), :root) == "/api/"
    assert Helpers.page_path(uri_with_script_name(), :root) == "/api/"
    assert Helpers.post_path(ScriptName, :show, 5) == "/api/posts/5"
    assert Helpers.post_path(conn_with_script_name(), :show, 5) == "/api/posts/5"
    assert Helpers.post_path(uri_with_script_name(), :show, 5) == "/api/posts/5"
  end

  test "urls use script name" do
    assert Helpers.page_url(ScriptName, :root) ==
           "https://example.com/api/"
    assert Helpers.page_url(conn_with_script_name(), :root) ==
           "https://example.com/api/"
    assert Helpers.page_url(uri_with_script_name(), :root) ==
           "https://example.com:123/api/"

    assert Helpers.post_url(ScriptName, :show, 5) ==
           "https://example.com/api/posts/5"
    assert Helpers.post_url(conn_with_script_name(), :show, 5) ==
           "https://example.com/api/posts/5"
    assert Helpers.post_url(uri_with_script_name(), :show, 5) ==
           "https://example.com:123/api/posts/5"
  end

  test "static does not use script name" do
    assert Helpers.static_path(conn_with_script_name(~w(foo)), "/images/foo.png") ==
           "/api/images/foo.png"

    assert Helpers.static_url(conn_with_script_name(~w(foo)), "/images/foo.png") ==
           "https://static.example.com/api/images/foo.png"
  end

  test "helpers properly encode named and query string params" do
    assert Router.Helpers.post_path(__MODULE__, :show, "my path", foo: "my param") ==
      "/posts/my%20path?foo=my+param"
  end
end

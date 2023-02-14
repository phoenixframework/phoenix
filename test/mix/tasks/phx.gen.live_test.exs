Code.require_file "../../../installer/test/mix_helper.exs", __DIR__

defmodule Mix.Tasks.Phx.Gen.LiveTest do
  use ExUnit.Case
  import MixHelper
  alias Mix.Tasks.Phx.Gen

  setup do
    Mix.Task.clear()
    :ok
  end

  defp in_tmp_live_project(test, func) do
    in_tmp_project(test, fn ->
      File.mkdir_p!("lib")
      File.touch!("lib/phoenix_web.ex")
      File.touch!("lib/phoenix.ex")
      func.()
    end)
  end

  defp in_tmp_live_umbrella_project(test, func) do
    in_tmp_umbrella_project(test, fn ->
      File.mkdir_p!("phoenix/lib")
      File.mkdir_p!("phoenix_web/lib")
      File.touch!("phoenix/lib/phoenix.ex")
      File.touch!("phoenix_web/lib/phoenix_web.ex")
      func.()
    end)
  end

  test "invalid mix arguments", config do
    in_tmp_live_project config.test, fn ->
      assert_raise Mix.Error, ~r/Expected the context, "blog", to be a valid module name/, fn ->
        Gen.Live.run(~w(blog Post posts title:string))
      end

      assert_raise Mix.Error, ~r/Expected the schema, "posts", to be a valid module name/, fn ->
        Gen.Live.run(~w(Post posts title:string))
      end

      assert_raise Mix.Error, ~r/The context and schema should have different names/, fn ->
        Gen.Live.run(~w(Blog Blog blogs))
      end

      assert_raise Mix.Error, ~r/Invalid arguments/, fn ->
        Gen.Live.run(~w(Blog.Post posts))
      end

      assert_raise Mix.Error, ~r/Invalid arguments/, fn ->
        Gen.Live.run(~w(Blog Post))
      end
    end
  end

  test "generates live resource and handles existing contexts", config do
    in_tmp_live_project config.test, fn ->
      Gen.Live.run(~w(Blog Post posts title slug:unique votes:integer cost:decimal
                      tags:array:text popular:boolean drafted_at:datetime
                      status:enum:unpublished:published:deleted
                      published_at:utc_datetime
                      published_at_usec:utc_datetime_usec
                      deleted_at:naive_datetime
                      deleted_at_usec:naive_datetime_usec
                      alarm:time
                      alarm_usec:time_usec
                      secret:uuid:redact announcement_date:date alarm:time
                      weight:float user_id:references:users))

      assert_file "lib/phoenix/blog/post.ex"
      assert_file "lib/phoenix/blog.ex"
      assert_file "test/phoenix/blog_test.exs"

      assert_file "lib/phoenix_web/live/post_live/index.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.PostLive.Index"
      end

      assert_file "lib/phoenix_web/live/post_live/show.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.PostLive.Show"
      end

      assert_file "lib/phoenix_web/live/post_live/form_component.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.PostLive.FormComponent"
      end

      assert [path] = Path.wildcard("priv/repo/migrations/*_create_posts.exs")
      assert_file path, fn file ->
        assert file =~ "create table(:posts)"
        assert file =~ "add :title, :string"
        assert file =~ "create unique_index(:posts, [:slug])"
      end

      assert_file "lib/phoenix_web/live/post_live/index.html.heex", fn file ->
        assert file =~ ~S|~p"/posts"|
      end

      assert_file "lib/phoenix_web/live/post_live/show.html.heex", fn file ->
        assert file =~ ~S|~p"/posts"|
      end

      assert_file "lib/phoenix_web/live/post_live/form_component.ex", fn file ->
        assert file =~ ~s(<.simple_form)
        assert file =~ ~s(<.input field={@form[:title]} type="text")
        assert file =~ ~s(<.input field={@form[:votes]} type="number")
        assert file =~ ~s(<.input field={@form[:cost]} type="number" label="Cost" step="any")
        assert file =~ """
                <.input
                  field={@form[:tags]}
                  type="select"
                  multiple
        """
        assert file =~ ~s(<.input field={@form[:popular]} type="checkbox")
        assert file =~ ~s(<.input field={@form[:drafted_at]} type="datetime-local")
        assert file =~ ~s(<.input field={@form[:published_at]} type="datetime-local")
        assert file =~ ~s(<.input field={@form[:deleted_at]} type="datetime-local")
        assert file =~ ~s(<.input field={@form[:announcement_date]} type="date")
        assert file =~ ~s(<.input field={@form[:alarm]} type="time")
        assert file =~ ~s(<.input field={@form[:secret]} type="text" label="Secret" />)
        assert file =~ """
                <.input
                  field={@form[:status]}
                  type="select"
        """
        assert file =~ ~s|Ecto.Enum.values(Phoenix.Blog.Post, :status)|

        refute file =~ ~s(<.input field={@form[:user_id]})
      end

      assert_file "test/phoenix_web/live/post_live_test.exs", fn file ->
        assert file =~ ~r"@invalid_attrs.*popular: false"
        assert file =~ ~S|~p"/posts"|
        assert file =~ ~S|~p"/posts/new"|
        assert file =~ ~S|~p"/posts/#{post}"|
        assert file =~ ~S|~p"/posts/#{post}/show/edit"|
      end

      send self(), {:mix_shell_input, :yes?, true}
      Gen.Live.run(~w(Blog Comment comments title:string))
      assert_received {:mix_shell, :info, ["You are generating into an existing context" <> _]}

      assert_file "lib/phoenix/blog/comment.ex"
      assert_file "test/phoenix_web/live/comment_live_test.exs", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentLiveTest"
      end

      assert [path] = Path.wildcard("priv/repo/migrations/*_create_comments.exs")
      assert_file path, fn file ->
        assert file =~ "create table(:comments)"
        assert file =~ "add :title, :string"
      end

      assert_file "lib/phoenix_web/live/comment_live/index.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentLive.Index"
      end

      assert_file "lib/phoenix_web/live/comment_live/show.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentLive.Show"
      end

      assert_file "lib/phoenix_web/live/comment_live/form_component.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentLive.FormComponent"
      end

      assert_receive {:mix_shell, :info, ["""

      Add the live routes to your browser scope in lib/phoenix_web/router.ex:

          live "/comments", CommentLive.Index, :index
          live "/comments/new", CommentLive.Index, :new
          live "/comments/:id/edit", CommentLive.Index, :edit

          live "/comments/:id", CommentLive.Show, :show
          live "/comments/:id/show/edit", CommentLive.Show, :edit
      """]}

      assert_receive({:mix_shell, :info, ["""

      You must update :phoenix_live_view to v0.18 or later and
      :phoenix_live_dashboard to v0.7 or later to use the features
      in this generator.
      """]})
    end
  end

  test "generates into existing context without prompt with --merge-with-existing-context", config do
    in_tmp_live_project config.test, fn ->
      Gen.Live.run(~w(Blog Post posts title))

      assert_file "lib/phoenix/blog.ex", fn file ->
        assert file =~ "def get_post!"
        assert file =~ "def list_posts"
        assert file =~ "def create_post"
        assert file =~ "def update_post"
        assert file =~ "def delete_post"
        assert file =~ "def change_post"
      end

      Gen.Live.run(~w(Blog Comment comments message:string --merge-with-existing-context))

      refute_received {:mix_shell, :info, ["You are generating into an existing context" <> _notice]}

      assert_file "lib/phoenix/blog.ex", fn file ->
        assert file =~ "def get_comment!"
        assert file =~ "def list_comments"
        assert file =~ "def create_comment"
        assert file =~ "def update_comment"
        assert file =~ "def delete_comment"
        assert file =~ "def change_comment"
      end
    end
  end

  test "with --web namespace generates namespaced web modules and directories", config do
    in_tmp_live_project config.test, fn ->
      Gen.Live.run(~w(Blog Post posts title:string --web Blog))

      assert_file "lib/phoenix/blog/post.ex"
      assert_file "lib/phoenix/blog.ex"
      assert_file "test/phoenix/blog_test.exs"

      assert_file "lib/phoenix_web/live/blog/post_live/index.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.Blog.PostLive.Index"
      end

      assert_file "lib/phoenix_web/live/blog/post_live/show.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.Blog.PostLive.Show"
      end

      assert_file "lib/phoenix_web/live/blog/post_live/form_component.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.Blog.PostLive.FormComponent"
      end

      assert [path] = Path.wildcard("priv/repo/migrations/*_create_posts.exs")
      assert_file path, fn file ->
        assert file =~ "create table(:posts)"
        assert file =~ "add :title, :string"
      end

      assert_file "lib/phoenix_web/live/blog/post_live/index.html.heex", fn file ->
        assert file =~ ~S|~p"/blog/posts"|
        assert file =~ ~S|~p"/blog/posts/#{post}/edit"|
        assert file =~ ~S|~p"/blog/posts/new"|
        assert file =~ ~S|~p"/blog/posts/#{post}"|
      end

      assert_file "lib/phoenix_web/live/blog/post_live/show.html.heex", fn file ->
        assert file =~ ~S|~p"/blog/posts"|
        assert file =~ ~S|~p"/blog/posts/#{@post}"|
        assert file =~ ~S|~p"/blog/posts/#{@post}/show/edit"|
      end

      assert_file "test/phoenix_web/live/blog/post_live_test.exs", fn file ->
        assert file =~ ~S|~p"/blog/posts"|
        assert file =~ ~S|~p"/blog/posts/new"|
        assert file =~ ~S|~p"/blog/posts/#{post}"|
        assert file =~ ~S|~p"/blog/posts/#{post}/show/edit"|
      end

      assert_receive {:mix_shell, :info, ["""

      Add the live routes to your Blog :browser scope in lib/phoenix_web/router.ex:

          scope "/blog", PhoenixWeb.Blog, as: :blog do
            pipe_through :browser
            ...

            live "/posts", PostLive.Index, :index
            live "/posts/new", PostLive.Index, :new
            live "/posts/:id/edit", PostLive.Index, :edit

            live "/posts/:id", PostLive.Show, :show
            live "/posts/:id/show/edit", PostLive.Show, :edit
          end
      """]}
    end
  end

  test "with --no-context skips context and schema file generation", config do
    in_tmp_live_project config.test, fn ->
      Gen.Live.run(~w(Blog Post posts title:string --no-context))

      refute_file "lib/phoenix/blog.ex"
      refute_file "lib/phoenix/blog/post.ex"
      assert Path.wildcard("priv/repo/migrations/*.exs") == []

      assert_file "lib/phoenix_web/live/post_live/index.ex"
      assert_file "lib/phoenix_web/live/post_live/show.ex"
      assert_file "lib/phoenix_web/live/post_live/form_component.ex"

      assert_file "lib/phoenix_web/live/post_live/index.html.heex"
      assert_file "lib/phoenix_web/live/post_live/show.html.heex"
      assert_file "test/phoenix_web/live/post_live_test.exs"
    end
  end

  test "with --no-schema skips schema file generation", config do
    in_tmp_live_project config.test, fn ->
      Gen.Live.run(~w(Blog Post posts title:string --no-schema))

      assert_file "lib/phoenix/blog.ex"
      refute_file "lib/phoenix/blog/post.ex"
      assert Path.wildcard("priv/repo/migrations/*.exs") == []

      assert_file "lib/phoenix_web/live/post_live/index.ex"
      assert_file "lib/phoenix_web/live/post_live/show.ex"
      assert_file "lib/phoenix_web/live/post_live/form_component.ex"

      assert_file "lib/phoenix_web/live/post_live/index.html.heex"
      assert_file "lib/phoenix_web/live/post_live/show.html.heex"
      assert_file "test/phoenix_web/live/post_live_test.exs"
    end
  end

  test "with --no-context does not emit warning when context exists", config do
    in_tmp_live_project config.test, fn ->
      Gen.Live.run(~w(Blog Post posts title:string))

      assert_file "lib/phoenix/blog.ex"
      assert_file "lib/phoenix/blog/post.ex"

      Gen.Live.run(~w(Blog Comment comments title:string --no-context))
      refute_received {:mix_shell, :info, ["You are generating into an existing context" <> _]}

      assert_file "lib/phoenix_web/live/comment_live/index.ex"
      assert_file "lib/phoenix_web/live/comment_live/show.ex"
      assert_file "lib/phoenix_web/live/comment_live/form_component.ex"

      assert_file "lib/phoenix_web/live/comment_live/index.html.heex"
      assert_file "lib/phoenix_web/live/comment_live/show.html.heex"
      assert_file "test/phoenix_web/live/comment_live_test.exs"
    end
  end

  test "with same singular and plural", config do
    in_tmp_live_project config.test, fn ->
      Gen.Live.run(~w(Tracker Series series value:integer))

      assert_file "lib/phoenix/tracker.ex"
      assert_file "lib/phoenix/tracker/series.ex"

      assert_file "lib/phoenix_web/live/series_live/index.ex", fn file ->
        assert file =~ "stream(socket, :series_collection, Tracker.list_series())"
      end

      assert_file "lib/phoenix_web/live/series_live/show.ex"
      assert_file "lib/phoenix_web/live/series_live/form_component.ex"

      assert_file "lib/phoenix_web/live/series_live/index.html.heex", fn file ->
        assert file =~ "@streams.series_collection"
      end

      assert_file "lib/phoenix_web/live/series_live/show.html.heex"
      assert_file "test/phoenix_web/live/series_live_test.exs"
    end
  end

  test "when more than 50 attributes are given", config do
    in_tmp_live_project config.test, fn ->
      long_attribute_list = Enum.map_join(0..55, " ", &("attribute#{&1}:string"))
      Gen.Live.run(~w(Blog Post posts title #{long_attribute_list}))

      assert_file "test/phoenix/blog_test.exs", fn file ->
        refute file =~ "...}"
      end
      assert_file "test/phoenix_web/live/post_live_test.exs", fn file ->
        refute file =~ "...}"
      end
    end
  end

  describe "inside umbrella" do
    test "without context_app generators config uses web dir", config do
      in_tmp_live_umbrella_project config.test, fn ->
        File.cd!("phoenix_web")

        Application.put_env(:phoenix, :generators, context_app: nil)
        Gen.Live.run(~w(Accounts User users name:string))

        assert_file "lib/phoenix/accounts.ex"
        assert_file "lib/phoenix/accounts/user.ex"

        assert_file "lib/phoenix_web/live/user_live/index.ex", fn file ->
          assert file =~ "defmodule PhoenixWeb.UserLive.Index"
          assert file =~ "use PhoenixWeb, :live_view"
        end

        assert_file "lib/phoenix_web/live/user_live/show.ex", fn file ->
          assert file =~ "defmodule PhoenixWeb.UserLive.Show"
          assert file =~ "use PhoenixWeb, :live_view"
        end

        assert_file "lib/phoenix_web/live/user_live/form_component.ex", fn file ->
          assert file =~ "defmodule PhoenixWeb.UserLive.FormComponent"
          assert file =~ "use PhoenixWeb, :live_component"
        end

        assert_file "test/phoenix_web/live/user_live_test.exs", fn file ->
          assert file =~ "defmodule PhoenixWeb.UserLiveTest"
        end
      end
    end

    test "raises with false context_app", config do
      in_tmp_live_umbrella_project config.test, fn ->
        Application.put_env(:phoenix, :generators, context_app: false)
        assert_raise Mix.Error, ~r/no context_app configured/, fn ->
          Gen.Live.run(~w(Accounts User users name:string))
        end
      end
    end

    test "with context_app generators config does not use web dir", config do
      in_tmp_live_umbrella_project config.test, fn ->
        File.mkdir!("another_app")
        Application.put_env(:phoenix, :generators, context_app: {:another_app, "another_app"})

        File.cd!("phoenix")

        Gen.Live.run(~w(Accounts User users name:string))

        assert_file "another_app/lib/another_app/accounts.ex"
        assert_file "another_app/lib/another_app/accounts/user.ex"


        assert_file "lib/phoenix/live/user_live/index.ex", fn file ->
          assert file =~ "defmodule Phoenix.UserLive.Index"
          assert file =~ "use Phoenix, :live_view"
        end

        assert_file "lib/phoenix/live/user_live/show.ex", fn file ->
          assert file =~ "defmodule Phoenix.UserLive.Show"
          assert file =~ "use Phoenix, :live_view"
        end

        assert_file "lib/phoenix/live/user_live/form_component.ex", fn file ->
          assert file =~ "defmodule Phoenix.UserLive.FormComponent"
          assert file =~ "use Phoenix, :live_component"
        end

        assert_file "test/phoenix/live/user_live_test.exs", fn file ->
          assert file =~ "defmodule Phoenix.UserLiveTest"
        end
      end
    end
  end
end

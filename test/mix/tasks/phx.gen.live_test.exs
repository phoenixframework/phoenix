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

      assert_file "lib/phoenix_web/live/modal_component.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.ModalComponent"
      end

      assert [path] = Path.wildcard("priv/repo/migrations/*_create_posts.exs")
      assert_file path, fn file ->
        assert file =~ "create table(:posts)"
        assert file =~ "add :title, :string"
        assert file =~ "create unique_index(:posts, [:slug])"
      end

      assert_file "lib/phoenix_web/live/post_live/index.html.leex", fn file ->
        assert file =~ " Routes.post_index_path(@socket, :index)"
      end

      assert_file "lib/phoenix_web/live/post_live/show.html.leex", fn file ->
        assert file =~ " Routes.post_index_path(@socket, :index)"
      end

      assert_file "lib/phoenix_web/live/post_live/form_component.html.leex", fn file ->
        assert file =~ ~s(<%= text_input f, :title %>)
        assert file =~ ~s(<%= number_input f, :votes %>)
        assert file =~ ~s(<%= number_input f, :cost, step: "any" %>)
        assert file =~ ~s(<%= multiple_select f, :tags, ["Option 1": "option1", "Option 2": "option2"] %>)
        assert file =~ ~s(<%= checkbox f, :popular %>)
        assert file =~ ~s(<%= datetime_select f, :drafted_at %>)
        assert file =~ ~s|<%= select f, :status, Ecto.Enum.values(Phoenix.Blog.Post, :status), prompt: "Choose a value" %>|
        assert file =~ ~s(<%= datetime_select f, :published_at %>)
        assert file =~ ~s(<%= datetime_select f, :deleted_at %>)
        assert file =~ ~s(<%= date_select f, :announcement_date %>)
        assert file =~ ~s(<%= time_select f, :alarm %>)
        assert file =~ ~s(<%= text_input f, :secret %>)

        assert file =~ ~s(<%= label f, :title %>)
        assert file =~ ~s(<%= label f, :votes %>)
        assert file =~ ~s(<%= label f, :cost %>)
        assert file =~ ~s(<%= label f, :tags %>)
        assert file =~ ~s(<%= label f, :popular %>)
        assert file =~ ~s(<%= label f, :drafted_at %>)
        assert file =~ ~s(<%= label f, :published_at %>)
        assert file =~ ~s(<%= label f, :deleted_at %>)
        assert file =~ ~s(<%= label f, :announcement_date %>)
        assert file =~ ~s(<%= label f, :alarm %>)
        assert file =~ ~s(<%= label f, :secret %>)

        refute file =~ ~s(<%= label f, :user_id)
        refute file =~ ~s(<%= number_input f, :user_id)
      end

      assert_file "test/phoenix_web/live/post_live_test.exs", fn file ->
        assert file =~ ~r"@invalid_attrs.*popular: false"
        assert file =~ " Routes.post_index_path(conn, :index)"
        assert file =~ " Routes.post_index_path(conn, :new)"
        assert file =~ " Routes.post_show_path(conn, :show, post)"
        assert file =~ " Routes.post_show_path(conn, :edit, post)"
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

      assert_file "lib/phoenix_web/live/modal_component.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.ModalComponent"
      end

      assert [path] = Path.wildcard("priv/repo/migrations/*_create_posts.exs")
      assert_file path, fn file ->
        assert file =~ "create table(:posts)"
        assert file =~ "add :title, :string"
      end

      assert_file "lib/phoenix_web/live/blog/post_live/index.html.leex", fn file ->
        assert file =~ " Routes.blog_post_index_path(@socket, :index)"
        assert file =~ " Routes.blog_post_index_path(@socket, :edit, post)"
        assert file =~ " Routes.blog_post_index_path(@socket, :new)"
        assert file =~ " Routes.blog_post_show_path(@socket, :show, post)"
      end

      assert_file "lib/phoenix_web/live/blog/post_live/show.html.leex", fn file ->
        assert file =~ " Routes.blog_post_index_path(@socket, :index)"
        assert file =~ " Routes.blog_post_show_path(@socket, :show, @post)"
        assert file =~ " Routes.blog_post_show_path(@socket, :edit, @post)"
      end

      assert_file "lib/phoenix_web/live/blog/post_live/form_component.html.leex"

      assert_file "test/phoenix_web/live/blog/post_live_test.exs", fn file ->
        assert file =~ " Routes.blog_post_index_path(conn, :index)"
        assert file =~ " Routes.blog_post_index_path(conn, :new)"
        assert file =~ " Routes.blog_post_show_path(conn, :show, post)"
        assert file =~ " Routes.blog_post_show_path(conn, :edit, post)"
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

      assert_file "lib/phoenix_web/live/modal_component.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.ModalComponent"
      end

      assert_file "lib/phoenix_web/live/post_live/index.html.leex"
      assert_file "lib/phoenix_web/live/post_live/show.html.leex"
      assert_file "lib/phoenix_web/live/post_live/form_component.html.leex"
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
      assert_file "lib/phoenix_web/live/modal_component.ex"

      assert_file "lib/phoenix_web/live/post_live/index.html.leex"
      assert_file "lib/phoenix_web/live/post_live/show.html.leex"
      assert_file "lib/phoenix_web/live/post_live/form_component.html.leex"
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

      assert_file "lib/phoenix_web/live/comment_live/index.html.leex"
      assert_file "lib/phoenix_web/live/comment_live/show.html.leex"
      assert_file "lib/phoenix_web/live/comment_live/form_component.html.leex"
      assert_file "test/phoenix_web/live/comment_live_test.exs"
    end
  end

  test "with same singular and plural", config do
    in_tmp_live_project config.test, fn ->
      Gen.Live.run(~w(Tracker Series series value:integer))

      assert_file "lib/phoenix/tracker.ex"
      assert_file "lib/phoenix/tracker/series.ex"

      assert_file "lib/phoenix_web/live/series_live/index.ex", fn file ->
        assert file =~ "assign(socket, :series_collection, list_series())"
      end

      assert_file "lib/phoenix_web/live/series_live/show.ex"
      assert_file "lib/phoenix_web/live/series_live/form_component.ex"
      assert_file "lib/phoenix_web/live/modal_component.ex"

      assert_file "lib/phoenix_web/live/series_live/index.html.leex", fn file ->
        assert file =~ "for series <- @series_collection do"
      end

      assert_file "lib/phoenix_web/live/series_live/show.html.leex"
      assert_file "lib/phoenix_web/live/series_live/form_component.html.leex"
      assert_file "test/phoenix_web/live/series_live_test.exs"
    end
  end

  test "when more than 50 attributes are given", config do
    in_tmp_live_project config.test, fn ->
      long_attribute_list = 0..55 |> Enum.map(&("attribute#{&1}:string")) |> Enum.join(" ")
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

        assert_file "lib/phoenix_web/live/user_live/form_component.html.leex"

        assert_file "lib/phoenix_web/live/modal_component.ex", fn file ->
          assert file =~ "defmodule PhoenixWeb.ModalComponent"
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

        assert_file "lib/phoenix/live/modal_component.ex", fn file ->
          assert file =~ "defmodule Phoenix.ModalComponent"
        end

        assert_file "lib/phoenix/live/user_live/form_component.html.leex"

        assert_file "test/phoenix/live/user_live_test.exs", fn file ->
          assert file =~ "defmodule Phoenix.UserLiveTest"
        end
      end
    end
  end
end

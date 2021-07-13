Code.require_file("../../../installer/test/mix_helper.exs", __DIR__)

defmodule Mix.Tasks.Phx.Gen.NotifierTest do
  use ExUnit.Case
  import MixHelper
  alias Mix.Tasks.Phx.Gen

  setup do
    Mix.Task.clear()
    :ok
  end

  test "new notifier", config do
    in_tmp_project(config.test, fn ->
      Gen.Notifier.run(~w(Accounts User welcome_user reset_password))

      assert_file("lib/phoenix/accounts/user_notifier.ex", fn file ->
        assert file =~ ~S|defmodule Phoenix.Accounts.UserNotifier do|
        assert file =~ ~S|import Swoosh.Email|
        assert file =~ ~S|alias Phoenix.Mailer|

        assert file =~ ~S|def deliver_welcome_user(%{name: name, email: email}) do|
        assert file =~ ~S|from({"Phoenix Team", "team@example.com"})|

        assert file =~ ~S|def deliver_reset_password(%{name: name, email: email}) do|
        assert file =~ ~S|from({"Phoenix Team", "team@example.com"})|

        assert file =~ ~S|Mailer.deliver()|
      end)

      assert_file("test/phoenix/accounts/user_notifier_test.exs", fn file ->
        assert file =~ ~S|defmodule Phoenix.Accounts.UserNotifierTest do|
      end)

      send(self(), {:mix_shell_input, :yes?, true})
      send(self(), {:mix_shell_input, :yes?, true})
      send(self(), {:mix_shell_input, :yes?, true})

      Gen.Notifier.run(~w(Accounts User account_confirmation))

      assert_received {:mix_shell, :info,
                       ["The following files conflict with new files to be generated:" <> notice]}

      assert notice =~ "user_notifier.ex"
      assert notice =~ "user_notifier_test.exs"

      assert_received {:mix_shell, :yes?, [question]}

      assert question =~ "Proceed with interactive overwrite?"

      assert_file("lib/phoenix/accounts/user_notifier.ex", fn file ->
        assert file =~ ~S|defmodule Phoenix.Accounts.UserNotifier do|
        assert file =~ ~S|import Swoosh.Email|
        assert file =~ ~S|alias Phoenix.Mailer|

        assert file =~ ~S|def deliver_account_confirmation(%{name: name, email: email}) do|
        assert file =~ ~S|from({"Phoenix Team", "team@example.com"})|

        refute file =~ ~S|def deliver_welcome_user(%{name: name, email: email}) do|
        refute file =~ ~S|def deliver_reset_password(%{name: name, email: email}) do|
      end)
    end)
  end

  test "generates nested notifier", config do
    in_tmp_project(config.test, fn ->
      Gen.Notifier.run(~w(Admin.Accounts User welcome_user reset_password))

      assert_file("lib/phoenix/admin/accounts/user_notifier.ex", fn file ->
        assert file =~ ~S|defmodule Phoenix.Admin.Accounts.UserNotifier do|
        assert file =~ ~S|import Swoosh.Email|
        assert file =~ ~S|alias Phoenix.Mailer|

        assert file =~ ~S|def deliver_welcome_user(%{name: name, email: email}) do|
        assert file =~ ~S|from({"Phoenix Team", "team@example.com"})|

        assert file =~ ~S|def deliver_reset_password(%{name: name, email: email}) do|
        assert file =~ ~S|from({"Phoenix Team", "team@example.com"})|

        assert file =~ ~S|Mailer.deliver()|
      end)
    end)
  end

  test "in an umbrella with a context_app, generates the notifier", config do
    in_tmp_umbrella_project(config.test, fn ->
      Application.put_env(:phoenix, :generators, context_app: {:another_app, "another_app"})
      Gen.Notifier.run(~w(Accounts User welcome_user reset_password))

      assert_file("another_app/lib/another_app/accounts/user_notifier.ex", fn file ->
        assert file =~ ~S|defmodule AnotherApp.Accounts.UserNotifier do|
        assert file =~ ~S|import Swoosh.Email|
        assert file =~ ~S|alias AnotherApp.Mailer|

        assert file =~ ~S|Mailer.deliver()|
      end)
    end)
  end

  test "invalid mix arguments", config do
    in_tmp_project(config.test, fn ->
      assert_raise Mix.Error, ~r/Expected the context, "blog", to be a valid module name/, fn ->
        Gen.Notifier.run(~w(blog Post new_post))
      end

      assert_raise Mix.Error, ~r/Expected the notifier, "posts", to be a valid module name/, fn ->
        Gen.Notifier.run(~w(Post posts new_post))
      end

      assert_raise Mix.Error,
                   ~r/Cannot generate context Phoenix because it has the same name as the application/,
                   fn ->
                     Gen.Notifier.run(~w(Phoenix Post new_blog_post))
                   end

      assert_raise Mix.Error,
                   ~r/Cannot generate notifier Phoenix because it has the same name as the application/,
                   fn ->
                     Gen.Notifier.run(~w(Blog Phoenix new_blog_post))
                   end

      assert_raise Mix.Error,
                   ~r/Cannot generate notifier "Post" because one of the messages is invalid: "NewPost"/,
                   fn ->
                     Gen.Notifier.run(~w(Blog Post NewPost))
                   end
    end)
  end
end

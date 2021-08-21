Code.require_file "../../../installer/test/mix_helper.exs", __DIR__

defmodule Mix.Tasks.Phx.Gen.AuthTest do
  use ExUnit.Case

  @moduletag :mix_phx_new

  import MixHelper
  alias Mix.Tasks.Phx.Gen

  setup do
    Mix.Task.clear()
    :ok
  end

  defp in_tmp_phx_project(test, additional_args \\ [], func) do
    in_tmp(test, fn ->
      Mix.Tasks.Phx.New.run(~w(my_app --no-install) ++ additional_args)
      in_project(:my_app, "my_app", fn _module ->
        func.()
      end)
    end)
  end

  defp in_tmp_phx_umbrella_project(test, func) do
    in_tmp(test, fn ->
      Mix.Tasks.Phx.New.run(~w(my_app --umbrella --no-install))
      File.cd!("my_app_umbrella", fn ->
        func.()
      end)
    end)
  end

  test "invalid mix arguments", config do
    in_tmp_phx_project(config.test, fn ->
      assert_raise Mix.Error, ~r/Expected the context, "accounts", to be a valid module name.*phx\.gen\.auth/s, fn ->
        Gen.Auth.run(~w(accounts User users))
      end

      assert_raise Mix.Error, ~r/Expected the schema, "user", to be a valid module name/, fn ->
        Gen.Auth.run(~w(Accounts user users))
      end

      assert_raise Mix.Error, ~r/The context and schema should have different names/, fn ->
        Gen.Auth.run(~w(User User users))
      end

      assert_raise Mix.Error, ~r/Cannot generate context MyApp because it has the same name as the application/, fn ->
        Gen.Auth.run(~w(MyApp User users))
      end

      assert_raise Mix.Error, ~r/Cannot generate schema MyApp because it has the same name as the application/, fn ->
        Gen.Auth.run(~w(Accounts MyApp users))
      end

      assert_raise Mix.Error, ~r/Invalid arguments/, fn ->
        Gen.Auth.run(~w())
      end

      assert_raise Mix.Error, ~r/Invalid arguments/, fn ->
        Gen.Auth.run(~w(Accounts))
      end

      assert_raise Mix.Error, ~r/Invalid arguments.*phx\.gen\.auth/s, fn ->
        Gen.Auth.run(~w(Accounts User users name:string))
      end

      assert_raise OptionParser.ParseError, ~r/unknown option/i, fn ->
        Gen.Auth.run(~w(Accounts User users --no-schema))
      end

      assert_raise Mix.Error, ~r/Unknown value for --hashing-lib/, fn ->
        Gen.Auth.run(~w(Accounts User users --hashing-lib unknown))
      end
    end)
  end

  test "generates with defaults", config do
    in_tmp_phx_project(config.test, fn ->
      Gen.Auth.run(
        ~w(Accounts User users),
        [ecto_adapter: Ecto.Adapters.Postgres, validate_dependencies?: false]
      )

      assert_file "config/test.exs", fn file ->
        assert file =~ "config :bcrypt_elixir, :log_rounds, 1"
      end

      assert_file "lib/my_app/accounts.ex"
      assert_file "lib/my_app/accounts/user.ex"
      assert_file "lib/my_app/accounts/user_token.ex"
      assert_file "lib/my_app/accounts/user_notifier.ex", fn file ->
        assert file =~ "defmodule MyApp.Accounts.UserNotifier do"
        assert file =~ "import Swoosh.Email"
        assert file =~ "Mailer.deliver(email)"
        assert file =~ ~s|deliver(user.email, "Confirmation instructions",|
        assert file =~ ~s|deliver(user.email, "Reset password instructions",|
        assert file =~ ~s|deliver(user.email, "Update email instructions",|
      end
      assert_file "test/my_app/accounts_test.exs"
      assert_file "test/support/fixtures/accounts_fixtures.ex"
      assert_file "lib/my_app_web/controllers/user_auth.ex"
      assert_file "test/my_app_web/controllers/user_auth_test.exs"
      assert_file "lib/my_app_web/views/user_confirmation_view.ex"
      assert_file "lib/my_app_web/templates/user_confirmation/new.html.eex"
      assert_file "lib/my_app_web/controllers/user_confirmation_controller.ex"
      assert_file "test/my_app_web/controllers/user_confirmation_controller_test.exs"
      assert_file "lib/my_app_web/templates/layout/_user_menu.html.eex"
      assert_file "lib/my_app_web/controllers/user_registration_controller.ex"
      assert_file "lib/my_app_web/views/user_registration_view.ex"
      assert_file "test/my_app_web/controllers/user_registration_controller_test.exs"
      assert_file "lib/my_app_web/controllers/user_reset_password_controller.ex"
      assert_file "lib/my_app_web/templates/user_reset_password/edit.html.eex"
      assert_file "lib/my_app_web/templates/user_reset_password/new.html.eex"
      assert_file "lib/my_app_web/views/user_reset_password_view.ex"
      assert_file "test/my_app_web/controllers/user_reset_password_controller_test.exs"
      assert_file "lib/my_app_web/controllers/user_session_controller.ex"
      assert_file "lib/my_app_web/templates/user_session/new.html.eex"
      assert_file "test/my_app_web/controllers/user_session_controller_test.exs"
      assert_file "lib/my_app_web/views/user_session_view.ex"
      assert_file "lib/my_app_web/controllers/user_settings_controller.ex"
      assert_file "lib/my_app_web/templates/user_settings/edit.html.eex"
      assert_file "lib/my_app_web/views/user_settings_view.ex"
      assert_file "test/my_app_web/controllers/user_settings_controller_test.exs"

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_users_auth_tables.exs")
      assert_file migration, fn file ->
        assert file =~ "create table(:users) do"
        assert file =~ "create table(:users_tokens) do"
      end

      assert_file "mix.exs", fn file ->
        assert file =~ ~s|{:bcrypt_elixir, "~> 2.0"},|
      end

      assert_file "lib/my_app_web/router.ex", fn file ->
        assert file =~ "import MyAppWeb.UserAuth"
        assert file =~ "plug :fetch_current_user"

        assert file =~ """
          ## Authentication routes

          scope "/", MyAppWeb do
            pipe_through [:browser, :redirect_if_user_is_authenticated]

            get "/users/register", UserRegistrationController, :new
            post "/users/register", UserRegistrationController, :create
            get "/users/log_in", UserSessionController, :new
            post "/users/log_in", UserSessionController, :create
            get "/users/reset_password", UserResetPasswordController, :new
            post "/users/reset_password", UserResetPasswordController, :create
            get "/users/reset_password/:token", UserResetPasswordController, :edit
            put "/users/reset_password/:token", UserResetPasswordController, :update
          end

          scope "/", MyAppWeb do
            pipe_through [:browser, :require_authenticated_user]

            get "/users/settings", UserSettingsController, :edit
            put "/users/settings", UserSettingsController, :update
            get "/users/settings/confirm_email/:token", UserSettingsController, :confirm_email
          end

          scope "/", MyAppWeb do
            pipe_through [:browser]

            delete "/users/log_out", UserSessionController, :delete
            get "/users/confirm", UserConfirmationController, :new
            post "/users/confirm", UserConfirmationController, :create
            get "/users/confirm/:token", UserConfirmationController, :edit
            post "/users/confirm/:token", UserConfirmationController, :update
          end
        """
      end

      assert_file "lib/my_app_web/templates/layout/app.html.eex", fn file ->
        assert file =~ ~s|<%= render "_user_menu.html", assigns %>|
      end

      assert_file "test/support/conn_case.ex", fn file ->
        assert file =~ "def register_and_log_in_user(%{conn: conn})"
        assert file =~ "def log_in_user(conn, user)"
      end

      assert_received {:mix_shell, :info, ["Unable to find the \"MyApp.Mailer\"" <> mailer_notice]}
      assert mailer_notice =~ ~s(A mailer module like the following is expected to be defined)
      assert mailer_notice =~ ~s(in your application in order to send emails.)
      assert mailer_notice =~ ~s(defmodule MyApp.Mailer do)
      assert mailer_notice =~ ~s(use Swoosh.Mailer, otp_app: :my_app)
      assert mailer_notice =~ ~s(def deps do)
      assert mailer_notice =~ ~s(https://hexdocs.pm/swoosh)
    end)
  end

  test "works with apps generated with --live", config do
    in_tmp_phx_project(config.test, ~w(--live), fn ->
      Gen.Auth.run(
        ~w(Accounts User users),
        [ecto_adapter: Ecto.Adapters.Postgres, validate_dependencies?: false]
      )

      assert_file "lib/my_app_web/templates/layout/root.html.leex", fn file ->
        assert file =~ ~s|<%= render "_user_menu.html", assigns %>|
      end

      assert_file "lib/my_app_web/templates/layout/app.html.eex", fn file ->
        refute file =~ ~s|<%= render "_user_menu.html", assigns %>|
      end
    end)
  end

  test "generates with --web option", config do
    in_tmp_phx_project(config.test, fn ->
      Gen.Auth.run(
        ~w(Accounts User users --web warehouse),
        [ecto_adapter: Ecto.Adapters.Postgres, validate_dependencies?: false]
      )

      assert_file "lib/my_app/accounts.ex"
      assert_file "lib/my_app/accounts/user.ex"
      assert_file "lib/my_app/accounts/user_token.ex"
      assert_file "lib/my_app/accounts/user_notifier.ex"
      assert_file "test/my_app/accounts_test.exs"

      assert_file "test/support/fixtures/accounts_fixtures.ex", fn file ->
        assert file =~ ~s|def valid_user_attributes(attrs \\\\ %{}) do|
      end

      assert_file "lib/my_app_web/controllers/warehouse/user_auth.ex", fn file ->
        assert file =~ "defmodule MyAppWeb.Warehouse.UserAuth do"
      end

      assert_file "test/my_app_web/controllers/warehouse/user_auth_test.exs", fn file ->
        assert file =~ "defmodule MyAppWeb.Warehouse.UserAuthTest do"
      end

      assert_file "lib/my_app_web/views/warehouse/user_confirmation_view.ex", fn file ->
        assert file =~ "defmodule MyAppWeb.Warehouse.UserConfirmationView do"
      end

      assert_file "lib/my_app_web/templates/warehouse/user_confirmation/new.html.eex", fn file ->
        assert file =~ ~S|<%= form_for :user, Routes.warehouse_user_confirmation_path(@conn, :create), fn f -> %>|
        assert file =~ ~S|<%= link "Register", to: Routes.warehouse_user_registration_path(@conn, :new) %>|
        assert file =~ ~S|<%= link "Log in", to: Routes.warehouse_user_session_path(@conn, :new) %>|
      end

      assert_file "lib/my_app_web/controllers/warehouse/user_confirmation_controller.ex", fn file ->
        assert file =~ "defmodule MyAppWeb.Warehouse.UserConfirmationController do"
      end

      assert_file "test/my_app_web/controllers/warehouse/user_confirmation_controller_test.exs", fn file ->
        assert file =~ "defmodule MyAppWeb.Warehouse.UserConfirmationControllerTest do"
      end

      assert_file "lib/my_app_web/templates/layout/_user_menu.html.eex", fn file ->
        assert file =~ ~S|<%= link "Settings", to: Routes.warehouse_user_settings_path(@conn, :edit) %>|
        assert file =~ ~S|<%= link "Log out", to: Routes.warehouse_user_session_path(@conn, :delete), method: :delete %>|
        assert file =~ ~S|<%= link "Register", to: Routes.warehouse_user_registration_path(@conn, :new) %>|
        assert file =~ ~S|<%= link "Log in", to: Routes.warehouse_user_session_path(@conn, :new) %>|
      end

      assert_file "lib/my_app_web/controllers/warehouse/user_registration_controller.ex", fn file ->
        assert file =~ "defmodule MyAppWeb.Warehouse.UserRegistrationController do"
      end

      assert_file "lib/my_app_web/views/warehouse/user_registration_view.ex", fn file ->
        assert file =~ "defmodule MyAppWeb.Warehouse.UserRegistrationView do"
      end

      assert_file "test/my_app_web/controllers/warehouse/user_registration_controller_test.exs", fn file ->
        assert file =~ "defmodule MyAppWeb.Warehouse.UserRegistrationControllerTest do"
      end

      assert_file "lib/my_app_web/controllers/warehouse/user_reset_password_controller.ex", fn file ->
        assert file =~ "defmodule MyAppWeb.Warehouse.UserResetPasswordController do"
      end

      assert_file "lib/my_app_web/templates/warehouse/user_reset_password/edit.html.eex", fn file ->
        assert file =~ ~S|<%= form_for @changeset, Routes.warehouse_user_reset_password_path(@conn, :update, @token), fn f -> %>|
        assert file =~ ~S|<%= link "Register", to: Routes.warehouse_user_registration_path(@conn, :new) %>|
        assert file =~ ~S|<%= link "Log in", to: Routes.warehouse_user_session_path(@conn, :new) %>|
      end

      assert_file "lib/my_app_web/templates/warehouse/user_reset_password/new.html.eex", fn file ->
        assert file =~ ~S|<%= form_for :user, Routes.warehouse_user_reset_password_path(@conn, :create), fn f -> %>|
        assert file =~ ~S|<%= link "Register", to: Routes.warehouse_user_registration_path(@conn, :new) %>|
        assert file =~ ~S|<%= link "Log in", to: Routes.warehouse_user_session_path(@conn, :new) %>|
      end

      assert_file "lib/my_app_web/views/warehouse/user_reset_password_view.ex", fn file ->
        assert file =~ "defmodule MyAppWeb.Warehouse.UserResetPasswordView do"
      end

      assert_file "test/my_app_web/controllers/warehouse/user_reset_password_controller_test.exs", fn file ->
        assert file =~ "defmodule MyAppWeb.Warehouse.UserResetPasswordControllerTest do"
      end

      assert_file "lib/my_app_web/controllers/warehouse/user_session_controller.ex", fn file ->
        assert file =~ "defmodule MyAppWeb.Warehouse.UserSessionController do"
      end

      assert_file "lib/my_app_web/templates/warehouse/user_session/new.html.eex", fn file ->
        assert file =~ ~S|<%= form_for @conn, Routes.warehouse_user_session_path(@conn, :create), [as: :user], fn f -> %>|
        assert file =~ ~S|<%= link "Register", to: Routes.warehouse_user_registration_path(@conn, :new) %>|
        assert file =~ ~S|<%= link "Forgot your password?", to: Routes.warehouse_user_reset_password_path(@conn, :new) %>|
      end

      assert_file "test/my_app_web/controllers/warehouse/user_session_controller_test.exs", fn file ->
        assert file =~ "defmodule MyAppWeb.Warehouse.UserSessionControllerTest do"
      end

      assert_file "lib/my_app_web/views/warehouse/user_session_view.ex", fn file ->
        assert file =~ "defmodule MyAppWeb.Warehouse.UserSessionView do"
      end

      assert_file "lib/my_app_web/controllers/warehouse/user_settings_controller.ex", fn file ->
        assert file =~ "defmodule MyAppWeb.Warehouse.UserSettingsController do"
      end

      assert_file "lib/my_app_web/templates/warehouse/user_settings/edit.html.eex", fn file ->
        assert file =~ ~S|<%= form_for @email_changeset, Routes.warehouse_user_settings_path(@conn, :update), [id: :update_email], fn f -> %>|
        assert file =~ ~S|<%= form_for @password_changeset, Routes.warehouse_user_settings_path(@conn, :update), [id: :update_password], fn f -> %>|
      end

      assert_file "lib/my_app_web/views/warehouse/user_settings_view.ex", fn file ->
        assert file =~ "defmodule MyAppWeb.Warehouse.UserSettingsView do"
      end

      assert_file "test/my_app_web/controllers/warehouse/user_settings_controller_test.exs", fn file ->
        assert file =~ "defmodule MyAppWeb.Warehouse.UserSettingsControllerTest do"
      end

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_users_auth_tables.exs")
      assert_file migration, fn file ->
        assert file =~ "create table(:users) do"
        assert file =~ "create table(:users_tokens) do"
      end

      assert_file "lib/my_app_web/router.ex", fn file ->
        assert file =~ "import MyAppWeb.Warehouse.UserAuth"
        assert file =~ "plug :fetch_current_user"

        assert file =~ """
          ## Authentication routes

          scope "/warehouse", MyAppWeb.Warehouse, as: :warehouse do
            pipe_through [:browser, :redirect_if_user_is_authenticated]

            get "/users/register", UserRegistrationController, :new
            post "/users/register", UserRegistrationController, :create
            get "/users/log_in", UserSessionController, :new
            post "/users/log_in", UserSessionController, :create
            get "/users/reset_password", UserResetPasswordController, :new
            post "/users/reset_password", UserResetPasswordController, :create
            get "/users/reset_password/:token", UserResetPasswordController, :edit
            put "/users/reset_password/:token", UserResetPasswordController, :update
          end

          scope "/warehouse", MyAppWeb.Warehouse, as: :warehouse do
            pipe_through [:browser, :require_authenticated_user]

            get "/users/settings", UserSettingsController, :edit
            put "/users/settings", UserSettingsController, :update
            get "/users/settings/confirm_email/:token", UserSettingsController, :confirm_email
          end

          scope "/warehouse", MyAppWeb.Warehouse, as: :warehouse do
            pipe_through [:browser]

            delete "/users/log_out", UserSessionController, :delete
            get "/users/confirm", UserConfirmationController, :new
            post "/users/confirm", UserConfirmationController, :create
            get "/users/confirm/:token", UserConfirmationController, :edit
            post "/users/confirm/:token", UserConfirmationController, :update
          end
        """
      end

      assert_file "lib/my_app_web/templates/layout/app.html.eex", fn file ->
        assert file =~ ~s|<%= render "_user_menu.html", assigns %>|
      end

      assert_file "test/support/conn_case.ex", fn file ->
        assert file =~ "def register_and_log_in_user(%{conn: conn})"
        assert file =~ "def log_in_user(conn, user)"
      end
    end)
  end

  describe "--database option" do
    test "when the database is postgres", config do
      in_tmp_phx_project(config.test, fn ->
        Gen.Auth.run(
          ~w(Accounts User users),
          [ecto_adapter: Ecto.Adapters.Postgres, validate_dependencies?: false]
        )

        assert [migration] = Path.wildcard("priv/repo/migrations/*_create_users_auth_tables.exs")
        assert_file migration, fn file ->
          assert file =~ ~r/execute "CREATE EXTENSION IF NOT EXISTS citext", ""$/m
          assert file =~ ~r/add :email, :citext, null: false$/m
        end

        assert_file "test/my_app_web/controllers/user_auth_test.exs", fn file ->
          assert file =~ ~r/use MyAppWeb\.ConnCase, async: true$/m
        end

        assert_file "test/my_app_web/controllers/user_confirmation_controller_test.exs", fn file ->
          assert file =~ ~r/use MyAppWeb\.ConnCase, async: true$/m
        end

        assert_file "test/my_app_web/controllers/user_registration_controller_test.exs", fn file ->
          assert file =~ ~r/use MyAppWeb\.ConnCase, async: true$/m
        end

        assert_file "test/my_app_web/controllers/user_reset_password_controller_test.exs", fn file ->
          assert file =~ ~r/use MyAppWeb\.ConnCase, async: true$/m
        end

        assert_file "test/my_app_web/controllers/user_session_controller_test.exs", fn file ->
          assert file =~ ~r/use MyAppWeb\.ConnCase, async: true$/m
        end

        assert_file "test/my_app_web/controllers/user_settings_controller_test.exs", fn file ->
          assert file =~ ~r/use MyAppWeb\.ConnCase, async: true$/m
        end
      end)
    end

    test "when the database is mysql", config do
      in_tmp_phx_project(config.test, fn ->
        Gen.Auth.run(
          ~w(Accounts User users),
          [ecto_adapter: Ecto.Adapters.MyXQL, validate_dependencies?: false]
        )

        assert [migration] = Path.wildcard("priv/repo/migrations/*_create_users_auth_tables.exs")
        assert_file migration, fn file ->
          refute file =~ ~r/execute "CREATE EXTENSION IF NOT EXISTS citext", ""$/m
          assert file =~ ~r/add :email, :string, null: false, size: 160$/m
        end

        assert_file "test/my_app_web/controllers/user_auth_test.exs", fn file ->
          assert file =~ ~r/use MyAppWeb\.ConnCase$/m
        end

        assert_file "test/my_app_web/controllers/user_confirmation_controller_test.exs", fn file ->
          assert file =~ ~r/use MyAppWeb\.ConnCase$/m
        end

        assert_file "test/my_app_web/controllers/user_registration_controller_test.exs", fn file ->
          assert file =~ ~r/use MyAppWeb\.ConnCase$/m
        end

        assert_file "test/my_app_web/controllers/user_reset_password_controller_test.exs", fn file ->
          assert file =~ ~r/use MyAppWeb\.ConnCase$/m
        end

        assert_file "test/my_app_web/controllers/user_session_controller_test.exs", fn file ->
          assert file =~ ~r/use MyAppWeb\.ConnCase$/m
        end

        assert_file "test/my_app_web/controllers/user_settings_controller_test.exs", fn file ->
          assert file =~ ~r/use MyAppWeb\.ConnCase$/m
        end
      end)
    end

    test "when the database is sqlite3", config do
      in_tmp_phx_project(config.test, fn ->
        Gen.Auth.run(
          ~w(Accounts User users),
          [ecto_adapter: Ecto.Adapters.SQLite3, validate_dependencies?: false]
        )

        assert [migration] = Path.wildcard("priv/repo/migrations/*_create_users_auth_tables.exs")
        assert_file migration, fn file ->
          refute file =~ ~r/execute "CREATE EXTENSION IF NOT EXISTS citext", ""$/m
          assert file =~ ~r/add :email, :string, null: false, collate: :nocase$/m
        end

        assert_file "test/my_app_web/controllers/user_auth_test.exs", fn file ->
          assert file =~ ~r/use MyAppWeb\.ConnCase$/m
        end

        assert_file "test/my_app_web/controllers/user_confirmation_controller_test.exs", fn file ->
          assert file =~ ~r/use MyAppWeb\.ConnCase$/m
        end

        assert_file "test/my_app_web/controllers/user_registration_controller_test.exs", fn file ->
          assert file =~ ~r/use MyAppWeb\.ConnCase$/m
        end

        assert_file "test/my_app_web/controllers/user_reset_password_controller_test.exs", fn file ->
          assert file =~ ~r/use MyAppWeb\.ConnCase$/m
        end

        assert_file "test/my_app_web/controllers/user_session_controller_test.exs", fn file ->
          assert file =~ ~r/use MyAppWeb\.ConnCase$/m
        end

        assert_file "test/my_app_web/controllers/user_settings_controller_test.exs", fn file ->
          assert file =~ ~r/use MyAppWeb\.ConnCase$/m
        end
      end)
    end

    test "when the database is mssql", config do
      in_tmp_phx_project(config.test, fn ->
        Gen.Auth.run(
          ~w(Accounts User users),
          [ecto_adapter: Ecto.Adapters.TDS, validate_dependencies?: false]
        )

        assert [migration] = Path.wildcard("priv/repo/migrations/*_create_users_auth_tables.exs")
        assert_file migration, fn file ->
          refute file =~ ~r/execute "CREATE EXTENSION IF NOT EXISTS citext", ""$/m
          assert file =~ ~r/add :email, :string, null: false, size: 160$/m
        end

        assert_file "test/my_app_web/controllers/user_auth_test.exs", fn file ->
          assert file =~ ~r/use MyAppWeb\.ConnCase$/m
        end

        assert_file "test/my_app_web/controllers/user_confirmation_controller_test.exs", fn file ->
          assert file =~ ~r/use MyAppWeb\.ConnCase$/m
        end

        assert_file "test/my_app_web/controllers/user_registration_controller_test.exs", fn file ->
          assert file =~ ~r/use MyAppWeb\.ConnCase$/m
        end

        assert_file "test/my_app_web/controllers/user_reset_password_controller_test.exs", fn file ->
          assert file =~ ~r/use MyAppWeb\.ConnCase$/m
        end

        assert_file "test/my_app_web/controllers/user_session_controller_test.exs", fn file ->
          assert file =~ ~r/use MyAppWeb\.ConnCase$/m
        end

        assert_file "test/my_app_web/controllers/user_settings_controller_test.exs", fn file ->
          assert file =~ ~r/use MyAppWeb\.ConnCase$/m
        end
      end)
    end
  end

  test "supports --binary_id option", config do
    in_tmp_phx_project(config.test, fn ->
      Gen.Auth.run(
        ~w(Accounts User users --binary-id),
        [ecto_adapter: Ecto.Adapters.Postgres, validate_dependencies?: false]
      )

      assert_file "lib/my_app/accounts/user.ex", fn file ->
        assert file =~ "@primary_key {:id, :binary_id, autogenerate: true}"
        assert file =~ "@foreign_key_type :binary_id"
      end

      assert_file "lib/my_app/accounts/user_token.ex", fn file ->
        assert file =~ "@primary_key {:id, :binary_id, autogenerate: true}"
        assert file =~ "@foreign_key_type :binary_id"
      end

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_users_auth_tables.exs")
      assert_file migration, fn file ->
        assert file =~ "create table(:users, primary_key: false)"
        assert file =~ "create table(:users_tokens, primary_key: false)"
        assert file =~ "add :id, :binary_id, primary_key: true"
      end
    end)
  end

  describe "--hashing-lib option" do
    test "when bcrypt", config do
      in_tmp_phx_project(config.test, fn ->
        Gen.Auth.run(
          ~w(Accounts User users --hashing-lib bcrypt),
          [ecto_adapter: Ecto.Adapters.Postgres, validate_dependencies?: false]
        )

        assert_file "mix.exs", fn file ->
          assert file =~ ~s|{:bcrypt_elixir, "~> 2.0"}|
        end

        assert_file "config/test.exs", fn file ->
          assert file =~ "config :bcrypt_elixir, :log_rounds, 1"
        end

        assert_file "lib/my_app/accounts/user.ex", fn file ->
          assert file =~ "Bcrypt.verify_pass(password, hashed_password)"
        end
      end)
    end

    test "when pbkdf2", config do
      in_tmp_phx_project(config.test, fn ->
        Gen.Auth.run(
          ~w(Accounts User users --hashing-lib pbkdf2),
          [ecto_adapter: Ecto.Adapters.Postgres, validate_dependencies?: false]
        )

        assert_file "mix.exs", fn file ->
          assert file =~ ~s|{:pbkdf2_elixir, "~> 1.0"}|
        end

        assert_file "config/test.exs", fn file ->
          assert file =~ "config :pbkdf2_elixir, :rounds, 1"
        end

        assert_file "lib/my_app/accounts/user.ex", fn file ->
          assert file =~ "Pbkdf2.verify_pass(password, hashed_password)"
        end
      end)
    end

    test "when argon2", config do
      in_tmp_phx_project(config.test, fn ->
        Gen.Auth.run(
          ~w(Accounts User users --hashing-lib argon2),
          [ecto_adapter: Ecto.Adapters.Postgres, validate_dependencies?: false]
        )

        assert_file "mix.exs", fn file ->
          assert file =~ ~s|{:argon2_elixir, "~> 2.0"}|
        end

        assert_file "config/test.exs", fn file ->
          assert file =~ """
          config :argon2_elixir, t_cost: 1, m_cost: 8
          """
        end

        assert_file "lib/my_app/accounts/user.ex", fn file ->
          assert file =~ "Argon2.verify_pass(password, hashed_password)"
        end
      end)
    end
  end

  test "with --table option", config do
    in_tmp_phx_project(config.test, fn ->
      Gen.Auth.run(
        ~w(Accounts User users --table my_users),
        [ecto_adapter: Ecto.Adapters.Postgres, validate_dependencies?: false]
      )

      assert_file "lib/my_app/accounts/user.ex", fn file ->
        assert file =~ ~S|schema "my_users" do|
      end

      assert_file "lib/my_app/accounts/user_token.ex", fn file ->
        assert file =~ ~S|schema "my_users_tokens" do|
      end

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_my_users_auth_tables.exs")
      assert_file migration, fn file ->
        assert file =~ "create table(:my_users) do"
        assert file =~ "create table(:my_users_tokens) do"
      end
    end)
  end

  describe "inside umbrella" do
    test "without context_app generators config uses web dir", config do
      in_tmp_phx_umbrella_project(config.test, fn ->
        in_project(:my_app, "apps/my_app", fn _module ->
          with_generator_env(:my_app_web, [context_app: nil], fn ->
            Gen.Auth.run(
              ~w(Accounts User users),
              [ecto_adapter: Ecto.Adapters.Postgres, validate_dependencies?: false]
            )
          end)
        end)

        assert_file "apps/my_app/lib/my_app/accounts.ex"
        assert_file "apps/my_app/lib/my_app/accounts/user.ex"
        assert_file "apps/my_app/lib/my_app/accounts/user_token.ex"
        assert_file "apps/my_app/lib/my_app/accounts/user_notifier.ex"
        assert_file "apps/my_app/test/my_app/accounts_test.exs"
        assert_file "apps/my_app/test/support/fixtures/accounts_fixtures.ex"
        assert_file "apps/my_app/lib/my_app_web/controllers/user_auth.ex"
        assert_file "apps/my_app/test/my_app_web/controllers/user_auth_test.exs"
        assert_file "apps/my_app/lib/my_app_web/views/user_confirmation_view.ex"
        assert_file "apps/my_app/lib/my_app_web/templates/user_confirmation/new.html.eex"
        assert_file "apps/my_app/lib/my_app_web/controllers/user_confirmation_controller.ex"
        assert_file "apps/my_app/test/my_app_web/controllers/user_confirmation_controller_test.exs"
        assert_file "apps/my_app/lib/my_app_web/templates/layout/_user_menu.html.eex"
        assert_file "apps/my_app/lib/my_app_web/controllers/user_registration_controller.ex"
        assert_file "apps/my_app/lib/my_app_web/views/user_registration_view.ex"
        assert_file "apps/my_app/test/my_app_web/controllers/user_registration_controller_test.exs"
        assert_file "apps/my_app/lib/my_app_web/controllers/user_reset_password_controller.ex"
        assert_file "apps/my_app/lib/my_app_web/templates/user_reset_password/edit.html.eex"
        assert_file "apps/my_app/lib/my_app_web/templates/user_reset_password/new.html.eex"
        assert_file "apps/my_app/lib/my_app_web/views/user_reset_password_view.ex"
        assert_file "apps/my_app/test/my_app_web/controllers/user_reset_password_controller_test.exs"
        assert_file "apps/my_app/lib/my_app_web/controllers/user_session_controller.ex"
        assert_file "apps/my_app/lib/my_app_web/templates/user_session/new.html.eex"
        assert_file "apps/my_app/test/my_app_web/controllers/user_session_controller_test.exs"
        assert_file "apps/my_app/lib/my_app_web/views/user_session_view.ex"
        assert_file "apps/my_app/lib/my_app_web/controllers/user_settings_controller.ex"
        assert_file "apps/my_app/lib/my_app_web/templates/user_settings/edit.html.eex"
        assert_file "apps/my_app/lib/my_app_web/views/user_settings_view.ex"
        assert_file "apps/my_app/test/my_app_web/controllers/user_settings_controller_test.exs"
      end)
    end

    test "with context_app generators config does not use web dir", config do
      in_tmp_phx_umbrella_project(config.test, fn ->
        in_project(:my_app_web, "apps/my_app_web", fn _module ->
          with_generator_env(:my_app_web, [context_app: :my_app], fn ->
            Gen.Auth.run(
              ~w(Accounts User users),
              [ecto_adapter: Ecto.Adapters.Postgres, validate_dependencies?: false]
            )
          end)
        end)

        assert_file "apps/my_app/lib/my_app/accounts.ex"
        assert_file "apps/my_app/lib/my_app/accounts/user.ex"
        assert_file "apps/my_app/lib/my_app/accounts/user_token.ex"
        assert_file "apps/my_app/lib/my_app/accounts/user_notifier.ex"
        assert_file "apps/my_app/test/my_app/accounts_test.exs"
        assert_file "apps/my_app/test/support/fixtures/accounts_fixtures.ex"
        assert_file "apps/my_app_web/lib/my_app_web/controllers/user_auth.ex"
        assert_file "apps/my_app_web/test/my_app_web/controllers/user_auth_test.exs"
        assert_file "apps/my_app_web/lib/my_app_web/views/user_confirmation_view.ex"
        assert_file "apps/my_app_web/lib/my_app_web/templates/user_confirmation/new.html.eex"
        assert_file "apps/my_app_web/lib/my_app_web/controllers/user_confirmation_controller.ex"
        assert_file "apps/my_app_web/test/my_app_web/controllers/user_confirmation_controller_test.exs"
        assert_file "apps/my_app_web/lib/my_app_web/templates/layout/_user_menu.html.eex"
        assert_file "apps/my_app_web/lib/my_app_web/controllers/user_registration_controller.ex"
        assert_file "apps/my_app_web/lib/my_app_web/views/user_registration_view.ex"
        assert_file "apps/my_app_web/test/my_app_web/controllers/user_registration_controller_test.exs"
        assert_file "apps/my_app_web/lib/my_app_web/controllers/user_reset_password_controller.ex"
        assert_file "apps/my_app_web/lib/my_app_web/templates/user_reset_password/edit.html.eex"
        assert_file "apps/my_app_web/lib/my_app_web/templates/user_reset_password/new.html.eex"
        assert_file "apps/my_app_web/lib/my_app_web/views/user_reset_password_view.ex"
        assert_file "apps/my_app_web/test/my_app_web/controllers/user_reset_password_controller_test.exs"
        assert_file "apps/my_app_web/lib/my_app_web/controllers/user_session_controller.ex"
        assert_file "apps/my_app_web/lib/my_app_web/templates/user_session/new.html.eex"
        assert_file "apps/my_app_web/test/my_app_web/controllers/user_session_controller_test.exs"
        assert_file "apps/my_app_web/lib/my_app_web/views/user_session_view.ex"
        assert_file "apps/my_app_web/lib/my_app_web/controllers/user_settings_controller.ex"
        assert_file "apps/my_app_web/lib/my_app_web/templates/user_settings/edit.html.eex"
        assert_file "apps/my_app_web/lib/my_app_web/views/user_settings_view.ex"
        assert_file "apps/my_app_web/test/my_app_web/controllers/user_settings_controller_test.exs"
      end)
    end

    test "raises with false context_app", config do
      in_tmp_phx_umbrella_project config.test, fn ->
        in_project(:my_app_web, "apps/my_app_web", fn _module ->
          with_generator_env(:my_app_web, [context_app: :false], fn ->
            assert_raise Mix.Error, ~r/no context_app configured/, fn ->
              Gen.Auth.run(
                ~w(Accounts User users),
                [ecto_adapter: Ecto.Adapters.Postgres, validate_dependencies?: false]
              )
              end
          end)
        end)
      end
    end
  end

  describe "user prompts" do
    test "when unable to inject dependencies in mix.exs", config do
      in_tmp_phx_project(config.test, fn ->
        File.write!("mix.exs", "")

        Gen.Auth.run(
          ~w(Accounts User users),
          [ecto_adapter: Ecto.Adapters.Postgres, validate_dependencies?: false]
        )

        assert_received {:mix_shell, :info, ["""

        Add your {:bcrypt_elixir, "~> 2.0"} dependency to mix.exs:

            defp deps do
              [
                {:bcrypt_elixir, "~> 2.0"},
                ...
              ]
            end
        """]}
      end)
    end

    test "when unable to inject authentication import into router.ex", config do
      in_tmp_phx_project(config.test, fn ->
        modify_file("lib/my_app_web/router.ex", fn file ->
          String.replace(file, "use MyAppWeb, :router", "")
        end)

        Gen.Auth.run(
          ~w(Accounts User users),
          [ecto_adapter: Ecto.Adapters.Postgres, validate_dependencies?: false]
        )

        assert_received {:mix_shell, :info, ["""

        Add your MyAppWeb.UserAuth import to lib/my_app_web/router.ex:

            defmodule MyAppWeb.Router do
              use MyAppWeb, :router

              # Import authentication plugs
              import MyAppWeb.UserAuth

              ...
            end

        """]}
      end)
    end

    test "when unable to inject plugs into router.ex", config do
      in_tmp_phx_project(config.test, fn ->
        modify_file("lib/my_app_web/router.ex", fn file ->
          String.replace(file, "plug :put_secure_browser_headers\n", "")
        end)

        Gen.Auth.run(
          ~w(Accounts User users),
          [ecto_adapter: Ecto.Adapters.Postgres, validate_dependencies?: false]
        )

        assert_received {:mix_shell, :info, ["""

        Add the :fetch_current_user plug to the :browser pipeline in lib/my_app_web/router.ex:

            pipeline :browser do
              ...
              plug :put_secure_browser_headers
              plug :fetch_current_user
            end

        """]}
      end)
    end

    test "when layout file is not found", config do
      in_tmp_phx_project(config.test, fn ->
        File.rm!("lib/my_app_web/templates/layout/app.html.eex")

        Gen.Auth.run(
          ~w(Accounts User users),
          [ecto_adapter: Ecto.Adapters.Postgres, validate_dependencies?: false]
        )

        assert_received {:mix_shell, :error, ["""

        Unable to find an application layout file to inject a render
        call for "_user_menu.html".

        Missing files:

          * lib/my_app_web/templates/layout/root.html.leex
          * lib/my_app_web/templates/layout/app.html.eex

        Please ensure this phoenix app was not generated with
        --no-html. If you have changed the name of your application
        layout file, please add the following code to it where you'd
        like "_user_menu.html" to be rendered.

            <%= render "_user_menu.html", assigns %>
        """]}
      end)
    end

    test "when user menu can't be injected into layout", config do
      in_tmp_phx_project(config.test, fn ->
        modify_file("lib/my_app_web/templates/layout/app.html.eex", fn _file ->
          ""
        end)

        Gen.Auth.run(
          ~w(Accounts User users),
          [ecto_adapter: Ecto.Adapters.Postgres, validate_dependencies?: false]
        )

        assert_received {:mix_shell, :info, ["""

        Add a render call for "_user_menu.html" to lib/my_app_web/templates/layout/app.html.eex:

          <nav>
            <%= render "_user_menu.html", assigns %>
          </nav>

        """]}
      end)
    end
  end

  test "allows templates to be overridden", config do
    in_tmp_phx_project(config.test, fn ->
      File.mkdir_p!("priv/templates/phx.gen.auth")
      File.write!("priv/templates/phx.gen.auth/_menu.html.eex", """
      <ul>
        <%%= if @current_<%= schema.singular %> do %>
          You're logged in
        <%% end %>
      </ul>
      """)

      Gen.Auth.run(
        ~w(Accounts Admin admins),
        [ecto_adapter: Ecto.Adapters.Postgres, validate_dependencies?: false]
      )

      assert_file "lib/my_app_web/templates/layout/_admin_menu.html.eex", fn file ->
        assert file =~ ~S|<%= if @current_admin do %>|
            assert file =~ ~S|You're logged in|
          end
      end)
  end

end

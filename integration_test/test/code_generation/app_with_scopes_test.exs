defmodule Phoenix.Integration.CodeGeneration.AppWithScopesTest do
  use Phoenix.Integration.CodeGeneratorCase, async: true

  describe "phx.gen.auth" do
    test "generates scope for phx.gen.live" do
      with_installer_tmp("scopes", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "scopes")

        mix_run!(~w(phx.gen.auth Accounts User users --live), app_root_path)
        # we need to wait, otherwise we'd generate two migrations with the same version...
        Process.sleep(1500)
        mix_run!(~w(phx.gen.live Blog Post posts title:string), app_root_path)

        modify_file(Path.join(app_root_path, "lib/scopes_web/router.ex"), fn file ->
          String.replace(
            file,
            """
            live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
            """,
            """
            live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email

                  live "/posts", PostLive.Index, :index
                  live "/posts/new", PostLive.Form, :new
                  live "/posts/:id", PostLive.Show, :show
                  live "/posts/:id/edit", PostLive.Form, :edit
            """
          )
        end)

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end

    test "generates scope for phx.gen.html" do
      with_installer_tmp("scopes", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "scopes")

        mix_run!(~w(phx.gen.auth Accounts User users --no-live), app_root_path)
        # we need to wait, otherwise we'd generate two migrations with the same version...
        Process.sleep(1500)
        mix_run!(~w(phx.gen.html Blog Post posts title:string), app_root_path)

        modify_file(Path.join(app_root_path, "lib/scopes_web/router.ex"), fn file ->
          String.replace(
            file,
            """
            get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
            """,
            """
            get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email

                resources "/posts", PostController
            """
          )
        end)

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end

    test "generates scope for phx.gen.json" do
      with_installer_tmp("scopes", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "scopes")

        mix_run!(~w(phx.gen.auth Accounts User users --no-live), app_root_path)
        # we need to wait, otherwise we'd generate two migrations with the same version...
        Process.sleep(1500)
        mix_run!(~w(phx.gen.json Blog Post posts title:string), app_root_path)

        modify_file(Path.join(app_root_path, "lib/scopes_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            scope "/api", ScopesWeb do
              pipe_through [
                :api,
                :fetch_session,
                :fetch_current_scope_for_user,
                :require_authenticated_user
              ]

              resources "/posts", PostController, except: [:new, :edit]
            end
          """)
        end)

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end
  end

  describe "custom scope" do
    test "route_prefix and route_access_path with all generators" do
      with_installer_tmp("scopes", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "scopes", ["--live"])

        # First generate authentication system
        mix_run!(~w(phx.gen.auth Accounts User users --live), app_root_path)

        # sleep to have fresh migration name
        Process.sleep(1500)
        mix_run!(~w(ecto.gen.migration AddOrganizationAndOrgUser), app_root_path)

        assert [migration] =
                 Path.wildcard(
                   Path.join(
                     app_root_path,
                     "priv/repo/migrations/*_add_organization_and_org_user.exs"
                   )
                 )

        File.write!(migration, """
        defmodule Scopes.Repo.Migrations.AddOrganizationAndOrgUser do
          use Ecto.Migration

          def change do
            create table(:organizations) do
              add :name, :string
              add :slug, :string
              add :user_id, references(:users, type: :id, on_delete: :delete_all)

              timestamps(type: :utc_datetime)
            end

            create unique_index(:organizations, [:slug])

            create table(:organizations_users) do
              add :role, :string
              add :organization_id, references(:organizations, on_delete: :nothing)
              add :user_id, references(:users, on_delete: :delete_all)

              timestamps(type: :utc_datetime)
            end

            create index(:organizations_users, [:organization_id])
            create index(:organizations_users, [:user_id])
          end
        end
        """)

        File.write!(Path.join(app_root_path, "lib/scopes/accounts/organization.ex"), """
        defmodule Scopes.Accounts.Organization do
          use Ecto.Schema
          import Ecto.Changeset
          alias Scopes.Accounts.User

          @derive {Phoenix.Param, key: :slug}
          schema "organizations" do
            field :name, :string
            field :slug, :string

            many_to_many :users, User, join_through: "organizations_users"

            timestamps(type: :utc_datetime)
          end

          @doc false
          def changeset(organization, attrs) do
            organization
            |> cast(attrs, [:name, :slug])
            |> validate_required([:name, :slug])
            |> unique_constraint(:slug)
          end
        end
        """)

        File.write!(Path.join(app_root_path, "lib/scopes/accounts/organization_user.ex"), """
        defmodule Scopes.Accounts.OrganizationUser do
          use Ecto.Schema
          import Ecto.Changeset

          schema "organizations_users" do
            field :role, :string
            belongs_to :organization, Scopes.Accounts.Organization
            belongs_to :user, Scopes.Accounts.User

            timestamps(type: :utc_datetime)
          end

          @doc false
          def changeset(organization_user, attrs, user_scope \\\\ nil) do
            organization_user
            |> cast(attrs, [:role, :organization_id, :user_id])
            |> validate_required([:role, :organization_id])
            |> maybe_put_user_id(user_scope)
          end

          defp maybe_put_user_id(changeset, %{user: %{id: user_id}}) do
            put_change(changeset, :user_id, user_id)
          end

          defp maybe_put_user_id(changeset, _), do: changeset
        end
        """)

        # Update context
        modify_file(Path.join(app_root_path, "lib/scopes/accounts.ex"), fn file ->
          inject_before_final_end(file, ~S'''
          ## Organization operations

          alias Scopes.Accounts.{Organization, OrganizationUser}

          @doc """
          Returns the list of organizations the user has access to.
          """
          def list_organizations(scope) do
            user_id = scope.user.id

            OrganizationUser
            |> where([ou], ou.user_id == ^user_id)
            |> join(:inner, [ou], o in Organization, on: o.id == ou.organization_id)
            |> select([_ou, o], o)
            |> Repo.all()
          end

          @doc """
          Gets an organization by slug.
          """
          def get_organization_by_slug!(scope, slug) when is_binary(slug) do
            # This function would typically check if the user has access to the organization
            # For this example, we'll just return the organization by slug
            Repo.one!(
              from o in Organization,
                join: ou in OrganizationUser, on: ou.organization_id == o.id,
                join: u in User, on: ou.user_id == u.id,
                where: u.id == ^scope.user.id,
                select: o
            )
          end

          @doc """
          Creates an organization.
          """
          def create_organization(scope, attrs \\ %{}) do
            %Organization{}
            |> Organization.changeset(attrs)
            |> Repo.insert()
            |> case do
              {:ok, organization} ->
                # Create a membership for the user who created the organization
                %OrganizationUser{}
                |> OrganizationUser.changeset(%{
                  organization_id: organization.id,
                  user_id: scope.user.id,
                  role: "owner"
                })
                |> Repo.insert()

                {:ok, organization}

              error ->
                error
            end
          end

          ''')
        end)

        # Update Scope struct to include organization
        modify_file(Path.join(app_root_path, "lib/scopes/accounts/scope.ex"), fn file ->
          String.replace(file, "defstruct user: nil", "defstruct user: nil, organization: nil")
          |> inject_before_final_end("""
          def put_organization(%__MODULE__{} = scope, %Scopes.Accounts.Organization{} = organization) do
            %{scope | organization: organization}
          end
          """)
        end)

        # Update the fixtures to support organization_scope_fixture
        modify_file(
          Path.join(app_root_path, "test/support/fixtures/accounts_fixtures.ex"),
          fn file ->
            inject_before_final_end(file, """

            def valid_organization_attributes(attrs \\\\ %{}) do
              Enum.into(attrs, %{
                name: "org\#{System.unique_integer()}",
                slug: "org\#{System.unique_integer()}"
              })
            end

            def organization_fixture(scope \\\\ user_scope_fixture()) do
              attrs = valid_organization_attributes()
              {:ok, organization} = Accounts.create_organization(scope, attrs)
              organization
            end

            def organization_scope_fixture(scope \\\\ user_scope_fixture()) do
              org = organization_fixture(scope)
              Scope.put_organization(scope, org)
            end
            """)
          end
        )

        # Add the register_and_log_in_user_with_org helper to ConnCase
        modify_file(Path.join(app_root_path, "test/support/conn_case.ex"), fn file ->
          inject_before_final_end(file, """

          def register_and_log_in_user_with_org(context) do
            %{conn: conn, user: user, scope: scope} = register_and_log_in_user(context)
            scope = Scopes.AccountsFixtures.organization_scope_fixture(scope)
            %{conn: conn, user: user, scope: scope}
          end
          """)
        end)

        # Modify the scopes config to include route_prefix and route_access_path for organization
        modify_file(Path.join(app_root_path, "config/config.exs"), fn file ->
          String.replace(
            file,
            """
            config :scopes, :scopes,
              user: [
                default: true,
                module: Scopes.Accounts.Scope,
                assign_key: :current_scope,
                access_path: [:user, :id],
                schema_key: :user_id,
                schema_type: :id,
                schema_table: :users,
                test_data_fixture: Scopes.AccountsFixtures,
                test_setup_helper: :register_and_log_in_user
              ]
            """,
            """
            config :scopes, :scopes,
            user: [
              default: true,
              module: Scopes.Accounts.Scope,
              assign_key: :current_scope,
              access_path: [:user, :id],
              schema_key: :user_id,
              schema_type: :id,
              schema_table: :users,
              test_data_fixture: Scopes.AccountsFixtures,
              test_setup_helper: :register_and_log_in_user
            ],
            organization: [
              module: Scopes.Accounts.Scope,
              assign_key: :current_scope,
              access_path: [:organization, :id],
              route_prefix: "/orgs/:slug",
              schema_key: :organization_id,
              schema_type: :id,
              schema_table: :organizations,
              test_data_fixture: Scopes.AccountsFixtures,
              test_setup_helper: :register_and_log_in_user_with_org
            ]
            """
          )
        end)

        # Extend the user auth module to assign org to scope
        modify_file(
          Path.join(app_root_path, "lib/scopes_web/user_auth.ex"),
          fn file ->
            inject_before_final_end(file, """

            def assign_org_to_scope(conn, _opts) do
              current_scope = conn.assigns.current_scope
              if slug = conn.params["slug"] do
                org = Scopes.Accounts.get_organization_by_slug!(current_scope, slug)
                assign(conn, :current_scope, Scopes.Accounts.Scope.put_organization(current_scope, org))
              else
                conn
              end
            end
            """)
          end
        )

        # Add the LiveView hook for organization assignment
        modify_file(
          Path.join(app_root_path, "lib/scopes_web/user_auth.ex"),
          fn file ->
            String.replace(
              file,
              """
                def on_mount(:mount_current_scope, _params, session, socket) do
                  {:cont, mount_current_scope(socket, session)}
                end
              """,
              """
              def on_mount(:mount_current_scope, _params, session, socket) do
                {:cont, mount_current_scope(socket, session)}
              end

              def on_mount(:assign_org_to_scope, %{"slug" => slug}, _session, socket) do
                socket =
                  case socket.assigns.current_scope do
                    %{organization: nil} = scope ->
                      org = Scopes.Accounts.get_organization_by_slug!(socket.assigns.current_scope, slug)
                      Phoenix.Component.assign(socket, :current_scope, Scope.put_organization(scope, org))

                    _ ->
                      socket
                  end

                {:cont, socket}
              end

              def on_mount(:assign_org_to_scope, _params, _session, socket), do: {:cont, socket}
              """
            )
          end
        )

        # Update the router to use the assign_org_to_scope plug
        modify_file(Path.join(app_root_path, "lib/scopes_web/router.ex"), fn file ->
          String.replace(file, "plug :fetch_current_scope_for_user", """
          plug :fetch_current_scope_for_user
          plug :assign_org_to_scope
          """)
        end)

        # Generate resources with all three generators - use different contexts to avoid naming conflicts
        Process.sleep(1500)

        mix_run!(
          ~w(phx.gen.html Blog1 Article articles title:string --scope organization),
          app_root_path
        )

        Process.sleep(1500)

        mix_run!(
          ~w(phx.gen.live Blog2 Post posts title:string --scope organization),
          app_root_path
        )

        Process.sleep(1500)

        mix_run!(
          ~w(phx.gen.json Blog3 Comment comments content:string --scope organization),
          app_root_path
        )

        # Update LiveView routes in router.ex
        modify_file(Path.join(app_root_path, "lib/scopes_web/router.ex"), fn file ->
          String.replace(
            file,
            "{ScopesWeb.UserAuth, :require_authenticated}",
            "{ScopesWeb.UserAuth, :require_authenticated}, {ScopesWeb.UserAuth, :assign_org_to_scope}"
          )
          |> String.replace(
            "live \"/users/settings/confirm-email/:token\", UserLive.Settings, :confirm_email",
            """
            live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email

            live "/orgs/:slug/posts", PostLive.Index, :index
            live "/orgs/:slug/posts/new", PostLive.Form, :new
            live "/orgs/:slug/posts/:id", PostLive.Show, :show
            live "/orgs/:slug/posts/:id/edit", PostLive.Form, :edit
            """
          )
        end)

        # Add the HTML routes
        modify_file(Path.join(app_root_path, "lib/scopes_web/router.ex"), fn file ->
          String.replace(
            file,
            "post \"/users/update-password\", UserSessionController, :update_password",
            """
            post "/users/update-password", UserSessionController, :update_password

            resources "/orgs/:slug/articles", ArticleController
            """
          )
        end)

        # Add the JSON API routes
        modify_file(Path.join(app_root_path, "lib/scopes_web/router.ex"), fn file ->
          router_code = """

          # API routes
          scope "/api", ScopesWeb do
            pipe_through [:api, :fetch_session, :fetch_current_scope_for_user, :assign_org_to_scope, :require_authenticated_user]

            resources "/orgs/:slug/comments", CommentController, except: [:new, :edit]
          end
          """

          inject_before_final_end(file, router_code)
        end)

        # Test HTML generator (Articles)
        assert_file(
          Path.join(app_root_path, "lib/scopes_web/controllers/article_html/index.html.heex"),
          fn file ->
            assert file =~
                     ~s|href={~p"/orgs/\#{@current_scope.organization}/articles/new"|

            assert file =~
                     ~s|navigate={~p"/orgs/\#{@current_scope.organization}/articles/\#{article}"|
          end
        )

        assert_file(
          Path.join(app_root_path, "lib/scopes_web/controllers/article_controller.ex"),
          fn file ->
            assert file =~
                     ~s|redirect(to: ~p"/orgs/\#{conn.assigns.current_scope.organization}/articles/\#{article}"|
          end
        )

        assert_file(
          Path.join(app_root_path, "test/scopes_web/controllers/article_controller_test.exs"),
          fn file ->
            assert file =~ ~s|~p"/orgs/\#{scope.organization}/articles"|
          end
        )

        # Test LiveView generator (Posts)
        assert_file(Path.join(app_root_path, "lib/scopes_web/live/post_live/index.ex"), fn file ->
          assert file =~
                   ~s|navigate={~p"/orgs/\#{@current_scope.organization}/posts/new"|

          assert file =~
                   ~s|JS.navigate(~p"/orgs/\#{@current_scope.organization}/posts/\#{post}")|
        end)

        assert_file(Path.join(app_root_path, "lib/scopes_web/live/post_live/show.ex"), fn file ->
          assert file =~ ~s|navigate={~p"/orgs/\#{@current_scope.organization}/posts"|
        end)

        assert_file(
          Path.join(app_root_path, "test/scopes_web/live/post_live_test.exs"),
          fn file ->
            assert file =~ ~s|~p"/orgs/\#{scope.organization}/posts"|
          end
        )

        # Test JSON generator (Comments)
        assert_file(
          Path.join(app_root_path, "lib/scopes_web/controllers/comment_controller.ex"),
          fn file ->
            assert file =~
                     ~s|~p"/api/orgs/\#{conn.assigns.current_scope.organization}/comments/\#{comment}"|
          end
        )

        assert_file(
          Path.join(app_root_path, "test/scopes_web/controllers/comment_controller_test.exs"),
          fn file ->
            assert file =~ ~s|~p"/api/orgs/\#{scope.organization}/comments"|
          end
        )

        # Final app validations
        assert_no_compilation_warnings(app_root_path)
        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end

    test "phx.gen.json" do
      with_installer_tmp("scopes", fn tmp_dir ->
        {app_root_path, _} = generate_phoenix_app(tmp_dir, "scopes")

        modify_file(Path.join(app_root_path, "config/config.exs"), fn file ->
          String.replace(file, "import Config", """
          import Config

          config :scopes, :scopes,
            user: [
              default: false,
              module: Scopes.UserScope,
              assign_key: :user_scope,
              access_path: [:u, :id],
              schema_key: :user_id,
              schema_type: :integer,
              schema_migration_type: :bigint,
              schema_table: nil,
              test_data_fixture: Scopes.UserScopeFixtures,
              test_setup_helper: :assign_scope
            ]\
          """)
        end)

        mix_run!(~w(phx.gen.json Blog Post posts title:string --scope user), app_root_path)

        File.write!(Path.join(app_root_path, "test/support/fixtures/user_scope_fixtures.ex"), """
        defmodule Scopes.UserScopeFixtures do
          alias Scopes.UserScope

          def user_scope_fixture(id \\\\ System.unique_integer()) do
            %UserScope{u: %{id: id}}
          end
        end
        """)

        modify_file(Path.join(app_root_path, "test/support/conn_case.ex"), fn file ->
          inject_before_final_end(file, """

            def assign_scope(%{conn: conn}) do
              id = System.unique_integer()
              scope = Scopes.UserScopeFixtures.user_scope_fixture(id)

              conn =
                conn
                |> Phoenix.ConnTest.init_test_session(%{})
                |> Plug.Conn.put_session(:user_id, id)

              %{conn: conn, scope: scope}
            end
          """)
        end)

        File.write!(Path.join(app_root_path, "lib/scopes/user_scope.ex"), """
        defmodule Scopes.UserScope do
          defstruct u: nil

          def new(attrs) do
            %Scopes.UserScope{u: attrs.u}
          end
        end
        """)

        modify_file(Path.join(app_root_path, "lib/scopes_web/router.ex"), fn file ->
          inject_before_final_end(file, """

            defp assign_scope(conn, _opts) do
              conn = Plug.Conn.fetch_session(conn)
              id = Plug.Conn.get_session(conn, :user_id) || raise "no user id found in session"
              assign(conn, :user_scope, Scopes.UserScope.new(%{u: %{id: id}}))
            end

            scope "/api", ScopesWeb do
              pipe_through [:api, :assign_scope]

              resources "/posts", PostController, except: [:new, :edit]
            end
          """)
        end)

        assert_no_compilation_warnings(app_root_path)
        assert_passes_formatter_check(app_root_path)
        drop_test_database(app_root_path)
        assert_tests_pass(app_root_path)
      end)
    end
  end
end

defmodule Mix.Tasks.Phx.Gen.Auth.InjectorTest do
  use ExUnit.Case, async: true

  alias Mix.Phoenix.{Context, Schema}
  alias Mix.Tasks.Phx.Gen.Auth.{HashingLibrary, Injector}

  describe "mix_dependency_inject/2" do
    test "injects before existing dependencies" do
      existing_file = """
      defmodule RainyDay.MixProject do
        use Mix.Project

        def project do
          [
            app: :rainy_day,
            version: "0.1.0",
            build_path: "../../_build",
            config_path: "../../config/config.exs",
            deps_path: "../../deps",
            lockfile: "../../mix.lock",
            elixir: "~> 1.7",
            elixirc_paths: elixirc_paths(Mix.env()),
            start_permanent: Mix.env() == :prod,
            aliases: aliases(),
            deps: deps()
          ]
        end

        # Configuration for the OTP application.
        #
        # Type `mix help compile.app` for more information.
        def application do
          [
            mod: {RainyDay.Application, []},
            extra_applications: [:logger, :runtime_tools]
          ]
        end

        # Specifies which paths to compile per environment.
        defp elixirc_paths(:test), do: ["lib", "test/support"]
        defp elixirc_paths(_), do: ["lib"]

        # Specifies your project dependencies.
        #
        # Type `mix help deps` for examples and options.
        defp deps do
          [
            {:phoenix_pubsub, "~> 2.0-dev", github: "phoenixframework/phoenix_pubsub"},
            {:ecto_sql, "~> 3.4"},
            {:postgrex, ">= 0.0.0"},
            {:jason, "~> 1.0"}
          ]
        end

        # Aliases are shortcuts or tasks specific to the current project.
        # For example, to create, migrate and run the seeds file at once:
        #
        #     $ mix ecto.setup
        #
        # See the documentation for `Mix` for more info on aliases.
        defp aliases do
          [
            "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
            "ecto.reset": ["ecto.drop", "ecto.setup"],
            test: ["ecto.create --quiet", "ecto.migrate", "test"]
          ]
        end
      end
      """

      inject = ~s|{:bcrypt_elixir, "~> 2.0"}|

      assert {:ok, new_file} = Injector.mix_dependency_inject(existing_file, inject)

      assert new_file == """
             defmodule RainyDay.MixProject do
               use Mix.Project

               def project do
                 [
                   app: :rainy_day,
                   version: "0.1.0",
                   build_path: "../../_build",
                   config_path: "../../config/config.exs",
                   deps_path: "../../deps",
                   lockfile: "../../mix.lock",
                   elixir: "~> 1.7",
                   elixirc_paths: elixirc_paths(Mix.env()),
                   start_permanent: Mix.env() == :prod,
                   aliases: aliases(),
                   deps: deps()
                 ]
               end

               # Configuration for the OTP application.
               #
               # Type `mix help compile.app` for more information.
               def application do
                 [
                   mod: {RainyDay.Application, []},
                   extra_applications: [:logger, :runtime_tools]
                 ]
               end

               # Specifies which paths to compile per environment.
               defp elixirc_paths(:test), do: ["lib", "test/support"]
               defp elixirc_paths(_), do: ["lib"]

               # Specifies your project dependencies.
               #
               # Type `mix help deps` for examples and options.
               defp deps do
                 [
                   {:bcrypt_elixir, "~> 2.0"},
                   {:phoenix_pubsub, "~> 2.0-dev", github: "phoenixframework/phoenix_pubsub"},
                   {:ecto_sql, "~> 3.4"},
                   {:postgrex, ">= 0.0.0"},
                   {:jason, "~> 1.0"}
                 ]
               end

               # Aliases are shortcuts or tasks specific to the current project.
               # For example, to create, migrate and run the seeds file at once:
               #
               #     $ mix ecto.setup
               #
               # See the documentation for `Mix` for more info on aliases.
               defp aliases do
                 [
                   "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
                   "ecto.reset": ["ecto.drop", "ecto.setup"],
                   test: ["ecto.create --quiet", "ecto.migrate", "test"]
                 ]
               end
             end
             """
    end

    test "when injected dependency already exists" do
      existing_file = """
      defmodule MyApp.MixFile do
        defp deps do
          [
            {:bcrypt_elixir, "~> 2.0"},
            {:ecto_sql, "~> 2.0"}
          ]
        end
      end
      """

      inject = ~s|{:bcrypt_elixir, "~> 2.0"}|

      assert :already_injected = Injector.mix_dependency_inject(existing_file, inject)
    end

    test "when unable to automatically inject" do
      existing_file = """
      defmodule MyApp.MixFile do
      end
      """

      inject = ~s|{:bcrypt_elixir, "~> 2.0"}|

      assert {:error, :unable_to_inject} = Injector.mix_dependency_inject(existing_file, inject)
    end
  end

  describe "inject_before_final_end/2" do
    test "injects code when not previously injected" do
      existing_code = """
      defmodule MyApp.Router do
        use MyApp, :router
      end
      """

      code_to_inject = """

        scope "/", MyApp do
          resources "/companies", CompanyController
        end
      """

      assert {:ok, new_code} = Injector.inject_before_final_end(existing_code, code_to_inject)

      assert new_code == """
             defmodule MyApp.Router do
               use MyApp, :router

               scope "/", MyApp do
                 resources "/companies", CompanyController
               end
             end
             """
    end

    test "returns :already_injected when code has been injected" do
      existing_code = """
      defmodule MyApp.Router do
        use MyApp, :router

        scope "/", MyApp do
          resources "/companies", CompanyController
        end
      end
      """

      code_to_inject = """

        scope "/", MyApp do
          resources "/companies", CompanyController
        end
      """

      assert :already_injected = Injector.inject_before_final_end(existing_code, code_to_inject)
    end
  end

  describe "inject_unless_contains/3" do
    test "injects when code doesn't already contain code_to_inject" do
      existing_code = """
      <html>
        <body>
          <h1>My App</h1>
        </body>
      </html>
      """

      code_to_inject = ~s|<.user_menu current_user={@current_user} />|

      assert {:ok, new_code} =
               Injector.inject_unless_contains(
                 existing_code,
                 code_to_inject,
                 &String.replace(&1, "<body>", "<body>\n    #{&2}")
               )

      assert new_code == """
             <html>
               <body>
                 <.user_menu current_user={@current_user} />
                 <h1>My App</h1>
               </body>
             </html>
             """
    end

    test "returns :already_injected when the existing code already contains code_to_inject" do
      existing_code = """
      <html>
        <body>
          <nav>
            <.user_menu current_user={@current_user} />
          </nav>
          <h1>My App</h1>
        </body>
      </html>
      """

      code_to_inject = ~s|<.user_menu current_user={@current_user} />|

      assert :already_injected =
               Injector.inject_unless_contains(
                 existing_code,
                 code_to_inject,
                 &String.replace(&1, "<body>", "<body>\n    #{&2}")
               )
    end

    test "returns {:error, :unable_to_inject} when no change is made" do
      existing_code = ""

      code_to_inject = ~s|<.user_menu current_user={@current_user} />|

      assert {:error, :unable_to_inject} =
               Injector.inject_unless_contains(
                 existing_code,
                 code_to_inject,
                 &String.replace(&1, "<body>", "<body>\n    #{&2}")
               )
    end
  end

  describe "test_config_inject/2" do
    test "injects after \"use Mix.Config\" when hashing_library is bcrypt" do
      {:ok, hashing_library} = HashingLibrary.build("bcrypt")

      input = """
      use Mix.Config
      """

      {:ok, injected} = Injector.test_config_inject(input, hashing_library)

      assert injected ==
               """
               use Mix.Config

               # Only in tests, remove the complexity from the password hashing algorithm
               config :bcrypt_elixir, :log_rounds, 1
               """
    end

    test "injects after \"use Mix.Config\" when hashing_library is pbkdf2" do
      {:ok, hashing_library} = HashingLibrary.build("pbkdf2")

      input = """
      use Mix.Config
      """

      {:ok, injected} = Injector.test_config_inject(input, hashing_library)

      assert injected ==
               """
               use Mix.Config

               # Only in tests, remove the complexity from the password hashing algorithm
               config :pbkdf2_elixir, :rounds, 1
               """
    end

    test "injects after \"use Mix.Config\" when hashing_library is argon2" do
      {:ok, hashing_library} = HashingLibrary.build("argon2")

      input = """
      use Mix.Config
      """

      {:ok, injected} = Injector.test_config_inject(input, hashing_library)

      assert injected ==
               """
               use Mix.Config

               # Only in tests, remove the complexity from the password hashing algorithm
               config :argon2_elixir, t_cost: 1, m_cost: 8
               """
    end

    test "injects after \"use Mix.Config\" when there is existing content" do
      {:ok, hashing_library} = HashingLibrary.build("bcrypt")

      input = """
      use Mix.Config

      # Print only warnings and errors during test
      config :logger, level: :warning
      """

      {:ok, injected} = Injector.test_config_inject(input, hashing_library)

      assert injected ==
               """
               use Mix.Config

               # Only in tests, remove the complexity from the password hashing algorithm
               config :bcrypt_elixir, :log_rounds, 1

               # Print only warnings and errors during test
               config :logger, level: :warning
               """
    end

    test "injects after \"import Config\" when there is existing content" do
      {:ok, hashing_library} = HashingLibrary.build("bcrypt")

      input = """
      import Config

      # Print only warnings and errors during test
      config :logger, level: :warning
      """

      {:ok, injected} = Injector.test_config_inject(input, hashing_library)

      assert injected ==
               """
               import Config

               # Only in tests, remove the complexity from the password hashing algorithm
               config :bcrypt_elixir, :log_rounds, 1

               # Print only warnings and errors during test
               config :logger, level: :warning
               """
    end

    test "injects when there are windows line endings" do
      {:ok, hashing_library} = HashingLibrary.build("bcrypt")

      input = """
      import Config\r
      \r
      # Print only warnings and errors during test\r
      config :logger, level: :warning\r
      """

      {:ok, injected} = Injector.test_config_inject(input, hashing_library)

      assert injected ==
               """
               import Config\r
               \r
               # Only in tests, remove the complexity from the password hashing algorithm\r
               config :bcrypt_elixir, :log_rounds, 1\r
               \r
               # Print only warnings and errors during test\r
               config :logger, level: :warning\r
               """
    end

    test "returns :already_injected when config is already found in file" do
      {:ok, hashing_library} = HashingLibrary.build("bcrypt")

      input = """
      import Config

      # Print only warnings and errors during test
      config :logger, level: :warning

      # Only in tests, remove the complexity from the password hashing algorithm
      config :bcrypt_elixir, :log_rounds, 1

      """

      assert :already_injected = Injector.test_config_inject(input, hashing_library)
    end

    test "returns :already_injected when config is already found when using windows line endings" do
      {:ok, hashing_library} = HashingLibrary.build("bcrypt")

      input = """
      import Config\r
      \r
      # Print only warnings and errors during test\r
      config :logger, level: :warning\r
      \r
      # Only in tests, remove the complexity from the password hashing algorithm\r
      config :bcrypt_elixir, :log_rounds, 1\r
      \r
      """

      assert :already_injected = Injector.test_config_inject(input, hashing_library)
    end

    test "returns {:error, :unable_to_inject} when file doesn't confine \"import Config\" or \"use Mix.Config\"" do
      {:ok, hashing_library} = HashingLibrary.build("bcrypt")

      input = ""

      assert {:error, :unable_to_inject} = Injector.test_config_inject(input, hashing_library)
    end
  end

  describe "test_config_help_text/2" do
    test "returns a string with the expected help text" do
      {:ok, hashing_library} = HashingLibrary.build("bcrypt")

      file_path = Path.expand("config/test.exs")

      assert Injector.test_config_help_text(file_path, hashing_library) ==
               """
               Add the following to config/test.exs:

                   # Only in tests, remove the complexity from the password hashing algorithm
                   config :bcrypt_elixir, :log_rounds, 1
               """
    end
  end

  describe "router_plug_inject/2" do
    test "injects after :put_secure_browser_headers" do
      schema = Schema.new("Accounts.User", "users", [], [])
      context = Context.new("Accounts", schema, [])

      input = """
      defmodule DemoWeb.Router do
        use DemoWeb, :router

        pipeline :browser do
          plug :accepts, ["html"]
          plug :fetch_session
          plug :fetch_flash
          plug :protect_from_forgery
          plug :put_secure_browser_headers
        end
      end
      """

      {:ok, injected} = Injector.router_plug_inject(input, context)

      assert injected ==
               """
               defmodule DemoWeb.Router do
                 use DemoWeb, :router

                 pipeline :browser do
                   plug :accepts, ["html"]
                   plug :fetch_session
                   plug :fetch_flash
                   plug :protect_from_forgery
                   plug :put_secure_browser_headers
                   plug :fetch_current_user
                 end
               end
               """
    end

    test "injects after :put_secure_browser_headers even when it has additional options" do
      schema = Schema.new("Accounts.User", "users", [], [])
      context = Context.new("Accounts", schema, [])

      input = """
      defmodule DemoWeb.Router do
        use DemoWeb, :router

        pipeline :browser do
          plug :accepts, ["html"]
          plug :fetch_session
          plug :fetch_flash
          plug :protect_from_forgery
          plug :put_secure_browser_headers, %{"content-security-policy" => @csp}
        end
      end
      """

      {:ok, injected} = Injector.router_plug_inject(input, context)

      assert injected ==
               """
               defmodule DemoWeb.Router do
                 use DemoWeb, :router

                 pipeline :browser do
                   plug :accepts, ["html"]
                   plug :fetch_session
                   plug :fetch_flash
                   plug :protect_from_forgery
                   plug :put_secure_browser_headers, %{"content-security-policy" => @csp}
                   plug :fetch_current_user
                 end
               end
               """
    end

    test "respects windows line endings" do
      schema = Schema.new("Accounts.User", "users", [], [])
      context = Context.new("Accounts", schema, [])

      input = """
      defmodule DemoWeb.Router do\r
        use DemoWeb, :router\r
      \r
        pipeline :browser do\r
          plug :accepts, ["html"]\r
          plug :fetch_session\r
          plug :fetch_flash\r
          plug :protect_from_forgery\r
          plug :put_secure_browser_headers\r
        end\r
      end\r
      """

      {:ok, injected} = Injector.router_plug_inject(input, context)

      assert injected ==
               """
               defmodule DemoWeb.Router do\r
                 use DemoWeb, :router\r
               \r
                 pipeline :browser do\r
                   plug :accepts, ["html"]\r
                   plug :fetch_session\r
                   plug :fetch_flash\r
                   plug :protect_from_forgery\r
                   plug :put_secure_browser_headers\r
                   plug :fetch_current_user\r
                 end\r
               end\r
               """
    end

    test "errors when :put_secure_browser_headers_is_missing" do
      schema = Schema.new("Accounts.User", "users", [], [])
      context = Context.new("Accounts", schema, [])

      input = """
      defmodule DemoWeb.Router do
        use DemoWeb, :router

        pipeline :browser do
          plug :accepts, ["html"]
          plug :fetch_session
          plug :fetch_flash
          plug :protect_from_forgery
        end
      end
      """

      assert {:error, :unable_to_inject} = Injector.router_plug_inject(input, context)
    end
  end

  describe "router_plug_help_text/2" do
    test "returns a string with the expected help text" do
      schema = Schema.new("Accounts.User", "users", [], [])
      context = Context.new("Accounts", schema, [])

      file_path = Path.expand("foo.ex")

      assert Injector.router_plug_help_text(file_path, context) ==
               """
               Add the :fetch_current_user plug to the :browser pipeline in foo.ex:

                   pipeline :browser do
                     ...
                     plug :put_secure_browser_headers
                     plug :fetch_current_user
                   end
               """
    end
  end

  describe "app_layout_menu_inject/2" do
    test "injects user menu at the bottom of nav section when it exists" do
      schema = Schema.new("Accounts.User", "users", [], [])

      template = """
      <!DOCTYPE html>
      <html lang="en">
        <head>
          <title>Demo · Phoenix Framework</title>
        </head>
        <body>
          <header>
            <section class="container">
              <nav>
                <ul>
                  <li><a href="https://hexdocs.pm/phoenix/overview.html">Get Started</a></li>
                  <%= if function_exported?(Routes, :live_dashboard_path, 2) do %>
                    <li><.link href={Routes.live_dashboard_path(@conn, :home)}>LiveDashboard</.link></li>
                  <% end %>
                </ul>
              </nav>
            </section>
          </header>
        </body>
      </html>
      """

      {:ok, template_str} = Injector.app_layout_menu_inject(schema, template)

      assert template_str ==
               """
               <!DOCTYPE html>
               <html lang="en">
                 <head>
                   <title>Demo · Phoenix Framework</title>
                 </head>
                 <body>
                   <header>
                     <section class="container">
                       <nav>
                         <ul>
                           <li><a href="https://hexdocs.pm/phoenix/overview.html">Get Started</a></li>
                           <%= if function_exported?(Routes, :live_dashboard_path, 2) do %>
                             <li><.link href={Routes.live_dashboard_path(@conn, :home)}>LiveDashboard</.link></li>
                           <% end %>
                         </ul>
                         <ul class="relative z-10 flex items-center gap-4 px-4 sm:px-6 lg:px-8 justify-end">
                           <%= if @current_user do %>
                             <li class="text-[0.8125rem] leading-6 text-zinc-900">
                               <%= @current_user.email %>
                             </li>
                             <li>
                               <.link
                                 href={~p"/users/settings"}
                                 class="text-[0.8125rem] leading-6 text-zinc-900 font-semibold hover:text-zinc-700"
                               >
                                 Settings
                               </.link>
                             </li>
                             <li>
                               <.link
                                 href={~p"/users/log_out"}
                                 method="delete"
                                 class="text-[0.8125rem] leading-6 text-zinc-900 font-semibold hover:text-zinc-700"
                               >
                                 Log out
                               </.link>
                             </li>
                           <% else %>
                             <li>
                               <.link
                                 href={~p"/users/register"}
                                 class="text-[0.8125rem] leading-6 text-zinc-900 font-semibold hover:text-zinc-700"
                               >
                                 Register
                               </.link>
                             </li>
                             <li>
                               <.link
                                 href={~p"/users/log_in"}
                                 class="text-[0.8125rem] leading-6 text-zinc-900 font-semibold hover:text-zinc-700"
                               >
                                 Log in
                               </.link>
                             </li>
                           <% end %>
                         </ul>
                       </nav>
                     </section>
                   </header>
                 </body>
               </html>
               """
    end

    test "injects user menu at the bottom of nav section when it exists with windows line endings" do
      schema = Schema.new("Accounts.User", "users", [], [])

      template = """
      <!DOCTYPE html>\r
      <html lang="en">\r
        <head>\r
          <title>Demo · Phoenix Framework</title>\r
        </head>\r
        <body>\r
          <header>\r
            <section class="container">\r
              <nav>\r
                <ul>\r
                  <li><a href="https://hexdocs.pm/phoenix/overview.html">Get Started</a></li>\r
                  <%= if function_exported?(Routes, :live_dashboard_path, 2) do %>\r
                    <li><.link href={Routes.live_dashboard_path(@conn, :home)}>LiveDashboard</.link></li>\r
                  <% end %>\r
                </ul>\r
              </nav>\r
            </section>\r
          </header>\r
        </body>\r
      </html>\r
      """

      {:ok, template_str} = Injector.app_layout_menu_inject(schema, template)

      assert template_str ==
               """
               <!DOCTYPE html>\r
               <html lang="en">\r
                 <head>\r
                   <title>Demo · Phoenix Framework</title>\r
                 </head>\r
                 <body>\r
                   <header>\r
                     <section class="container">\r
                       <nav>\r
                         <ul>\r
                           <li><a href="https://hexdocs.pm/phoenix/overview.html">Get Started</a></li>\r
                           <%= if function_exported?(Routes, :live_dashboard_path, 2) do %>\r
                             <li><.link href={Routes.live_dashboard_path(@conn, :home)}>LiveDashboard</.link></li>\r
                           <% end %>\r
                         </ul>\r
                         <ul class="relative z-10 flex items-center gap-4 px-4 sm:px-6 lg:px-8 justify-end">\r
                           <%= if @current_user do %>\r
                             <li class="text-[0.8125rem] leading-6 text-zinc-900">\r
                               <%= @current_user.email %>\r
                             </li>\r
                             <li>\r
                               <.link\r
                                 href={~p"/users/settings"}\r
                                 class="text-[0.8125rem] leading-6 text-zinc-900 font-semibold hover:text-zinc-700"\r
                               >\r
                                 Settings\r
                               </.link>\r
                             </li>\r
                             <li>\r
                               <.link\r
                                 href={~p"/users/log_out"}\r
                                 method="delete"\r
                                 class="text-[0.8125rem] leading-6 text-zinc-900 font-semibold hover:text-zinc-700"\r
                               >\r
                                 Log out\r
                               </.link>\r
                             </li>\r
                           <% else %>\r
                             <li>\r
                               <.link\r
                                 href={~p"/users/register"}\r
                                 class="text-[0.8125rem] leading-6 text-zinc-900 font-semibold hover:text-zinc-700"\r
                               >\r
                                 Register\r
                               </.link>\r
                             </li>\r
                             <li>\r
                               <.link\r
                                 href={~p"/users/log_in"}\r
                                 class="text-[0.8125rem] leading-6 text-zinc-900 font-semibold hover:text-zinc-700"\r
                               >\r
                                 Log in\r
                               </.link>\r
                             </li>\r
                           <% end %>\r
                         </ul>\r
                       </nav>\r
                     </section>\r
                   </header>\r
                 </body>\r
               </html>\r
               """
    end

    test "injects render user_menu after the opening body tag" do
      schema = Schema.new("Accounts.User", "users", [], [])

      template = """
      <!DOCTYPE html>
      <html lang="en">
        <head>
          <title>Demo · Phoenix Framework</title>
        </head>
        <body>
          <main class="container">
            <p class="alert alert-info" role="alert"><%= Phoenix.Flash.get(@conn, :info) %></p>
            <p class="alert alert-danger" role="alert"><%= Phoenix.Flash.get(@conn, :error) %></p>
            <%= @inner_content %>
          </main>
        </body>
      </html>
      """

      {:ok, template_str} = Injector.app_layout_menu_inject(schema, template)

      assert template_str ==
               """
               <!DOCTYPE html>
               <html lang="en">
                 <head>
                   <title>Demo · Phoenix Framework</title>
                 </head>
                 <body>
                   <ul class="relative z-10 flex items-center gap-4 px-4 sm:px-6 lg:px-8 justify-end">
                     <%= if @current_user do %>
                       <li class="text-[0.8125rem] leading-6 text-zinc-900">
                         <%= @current_user.email %>
                       </li>
                       <li>
                         <.link
                           href={~p"/users/settings"}
                           class="text-[0.8125rem] leading-6 text-zinc-900 font-semibold hover:text-zinc-700"
                         >
                           Settings
                         </.link>
                       </li>
                       <li>
                         <.link
                           href={~p"/users/log_out"}
                           method="delete"
                           class="text-[0.8125rem] leading-6 text-zinc-900 font-semibold hover:text-zinc-700"
                         >
                           Log out
                         </.link>
                       </li>
                     <% else %>
                       <li>
                         <.link
                           href={~p"/users/register"}
                           class="text-[0.8125rem] leading-6 text-zinc-900 font-semibold hover:text-zinc-700"
                         >
                           Register
                         </.link>
                       </li>
                       <li>
                         <.link
                           href={~p"/users/log_in"}
                           class="text-[0.8125rem] leading-6 text-zinc-900 font-semibold hover:text-zinc-700"
                         >
                           Log in
                         </.link>
                       </li>
                     <% end %>
                   </ul>
                   <main class="container">
                     <p class="alert alert-info" role="alert"><%= Phoenix.Flash.get(@conn, :info) %></p>
                     <p class="alert alert-danger" role="alert"><%= Phoenix.Flash.get(@conn, :error) %></p>
                     <%= @inner_content %>
                   </main>
                 </body>
               </html>
               """
    end

    test "works with windows line endings" do
      schema = Schema.new("Accounts.User", "users", [], [])

      template = """
      <!DOCTYPE html>\r
      <html lang="en">\r
        <head>\r
          <title>Demo · Phoenix Framework</title>\r
        </head>\r
        <body>\r
          <main class="container">\r
            <p class="alert alert-info" role="alert"><%= Phoenix.Flash.get(@conn, :info) %></p>\r
            <p class="alert alert-danger" role="alert"><%= Phoenix.Flash.get(@conn, :error) %></p>\r
            <%= @inner_content %>\r
          </main>\r
        </body>\r
      </html>\r
      """

      {:ok, template_str} = Injector.app_layout_menu_inject(schema, template)

      assert template_str ==
               """
               <!DOCTYPE html>\r
               <html lang="en">\r
                 <head>\r
                   <title>Demo · Phoenix Framework</title>\r
                 </head>\r
                 <body>\r
                   <ul class="relative z-10 flex items-center gap-4 px-4 sm:px-6 lg:px-8 justify-end">\r
                     <%= if @current_user do %>\r
                       <li class="text-[0.8125rem] leading-6 text-zinc-900">\r
                         <%= @current_user.email %>\r
                       </li>\r
                       <li>\r
                         <.link\r
                           href={~p"/users/settings"}\r
                           class="text-[0.8125rem] leading-6 text-zinc-900 font-semibold hover:text-zinc-700"\r
                         >\r
                           Settings\r
                         </.link>\r
                       </li>\r
                       <li>\r
                         <.link\r
                           href={~p"/users/log_out"}\r
                           method="delete"\r
                           class="text-[0.8125rem] leading-6 text-zinc-900 font-semibold hover:text-zinc-700"\r
                         >\r
                           Log out\r
                         </.link>\r
                       </li>\r
                     <% else %>\r
                       <li>\r
                         <.link\r
                           href={~p"/users/register"}\r
                           class="text-[0.8125rem] leading-6 text-zinc-900 font-semibold hover:text-zinc-700"\r
                         >\r
                           Register\r
                         </.link>\r
                       </li>\r
                       <li>\r
                         <.link\r
                           href={~p"/users/log_in"}\r
                           class="text-[0.8125rem] leading-6 text-zinc-900 font-semibold hover:text-zinc-700"\r
                         >\r
                           Log in\r
                         </.link>\r
                       </li>\r
                     <% end %>\r
                   </ul>\r
                   <main class="container">\r
                     <p class="alert alert-info" role="alert"><%= Phoenix.Flash.get(@conn, :info) %></p>\r
                     <p class="alert alert-danger" role="alert"><%= Phoenix.Flash.get(@conn, :error) %></p>\r
                     <%= @inner_content %>\r
                   </main>\r
                 </body>\r
               </html>\r
               """
    end

    test "returns :already_injected when render is already found in file" do
      schema = Schema.new("Accounts.User", "users", [], [])

      template = """
      <!DOCTYPE html>
      <html lang="en">
        <head>
          <title>Demo · Phoenix Framework</title>
        </head>
        <body>
          <div class="my-header">
            <ul>
              <%= if @current_user do %>
                <li><%= @current_user.email %></li>
                <li><.link href={~p"/users/settings"}>Settings</.link></li>
                <li><.link href={~p"/users/log_out"} method="delete">Log out</.link></li>
              <% else %>
                <li><.link href={~p"/users/register"}>Register</.link></li>
                <li><.link href={~p"/users/log_in"}>Log in</.link></li>
              <% end %>
            </ul>
          </div>
          <main class="container">
            <p class="alert alert-info" role="alert"><%= Phoenix.Flash.get(@conn, :info) %></p>
            <p class="alert alert-danger" role="alert"><%= Phoenix.Flash.get(@conn, :error) %></p>
            <%= @inner_content %>
          </main>
        </body>
      </html>
      """

      assert :already_injected = Injector.app_layout_menu_inject(schema, template)
    end

    test "returns {:error, :unable_to_inject} when the body tag isn't found" do
      schema = Schema.new("Accounts.User", "users", [], [])
      assert {:error, :unable_to_inject} = Injector.app_layout_menu_inject(schema, "")
    end
  end

  describe "app_layout_menu_help_text/2" do
    test "returns a string with the expected help text" do
      schema = Schema.new("Accounts.User", "users", [], [])
      file_path = Path.expand("foo.ex")

      assert Injector.app_layout_menu_help_text(file_path, schema) =~
               "Add the following user menu"
    end
  end
end

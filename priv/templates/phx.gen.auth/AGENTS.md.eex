## Authentication

- **Always** handle authentication flow at the router level with proper redirects
- **Always** be mindful of where to place routes. `phx.gen.auth` creates multiple router plugs<%= if live? do %> and `live_session` scopes<% end %>:
  - A plug `:fetch_<%= scope_config.scope.assign_key %>_for_<%= schema.singular %>` that is included in the default browser pipeline
  - A plug `:require_authenticated_<%= schema.singular %>` that redirects to the log in page when the <%= schema.singular %> is not authenticated<%= if live? do %>
  - A `live_session :current_<%= schema.singular %>` scope - for routes that need the current <%= schema.singular %> but don't require authentication, similar to `:fetch_<%= scope_config.scope.assign_key %>_for_<%= schema.singular %>`
  - A `live_session :require_authenticated_<%= schema.singular %>` scope - for routes that require authentication, similar to the plug with the same name<% end %>
  - In both cases, a `@<%= scope_config.scope.assign_key %>` is assigned to the Plug connection<%= if live? do %> and LiveView socket<% end %>
  - A plug `redirect_if_<%= schema.singular %>_is_authenticated` that redirects to a default path in case the <%= schema.singular %> is authenticated - useful for a registration page that should only be shown to unauthenticated <%= schema.plural %>
- **Always let the user know in which router scopes<%= if live? do%>, `live_session`,<% end %> and pipeline you are placing the route, AND SAY WHY**
- `phx.gen.auth` assigns the `<%= scope_config.scope.assign_key %>` assign - it **does not assign a `current_<%= schema.singular %>` assign**
- Always pass the assign `<%= scope_config.scope.assign_key %>` to context modules as first argument. When performing queries, use `<%= scope_config.scope.assign_key %>.<%= schema.singular %>` to filter the query results
- To derive/access `current_<%= schema.singular %>` in templates, **always use the `@<%= scope_config.scope.assign_key %>.<%= schema.singular %>`**, never use **`@current_<%= schema.singular %>`** in templates<%= if live? do %> or LiveViews
- **Never** duplicate `live_session` names. A `live_session :current_<%= schema.singular %>` can only be defined __once__ in the router, so all routes for the `live_session :current_<%= schema.singular %>`  must be grouped in a single block<% end %>
- Anytime you hit `<%= scope_config.scope.assign_key %>` errors or the logged in session isn't displaying the right content, **always double check the router and ensure you are using the correct plug<%= if live? do %> and `live_session`<% end %> as described below**

### Routes that require authentication

<%= if live? do %>LiveViews that require login should **always be placed inside the __existing__ `live_session :require_authenticated_<%= schema.singular %>` block**:

    scope "/", AppWeb do
      pipe_through [:browser, :require_authenticated_<%= schema.singular %>]

      live_session :require_authenticated_<%= schema.singular %>,
        on_mount: [{<%= inspect auth_module %>, :require_authenticated}] do
        # phx.gen.auth generated routes
        live "/<%= schema.plural %>/settings", <%= inspect schema.alias %>Live.Settings, :edit
        live "/<%= schema.plural %>/settings/confirm-email/:token", <%= inspect schema.alias %>Live.Settings, :confirm_email
        # our own routes that require logged in <%= schema.singular %>
        live "/", MyLiveThatRequiresAuth, :index
      end
    end

<% end %>Controller routes must be placed in a scope that sets the `:require_authenticated_<%= schema.singular %>` plug:

    scope "/", AppWeb do
      pipe_through [:browser, :require_authenticated_<%= schema.singular %>]

      get "/", MyControllerThatRequiresAuth, :index
    end

### Routes that work with or without authentication

<%= if live? do %>LiveViews that can work with or without authentication, **always use the __existing__ `:current_<%= schema.singular %>` scope**, ie:

    scope "/", MyAppWeb do
      pipe_through [:browser]

      live_session :current_<%= schema.singular %>,
        on_mount: [{<%= inspect auth_module %>, :mount_<%= scope_config.scope.assign_key %>}] do
        # our own routes that work with or without authentication
        live "/", PublicLive
      end
    end

<% end %>Controllers automatically have the `<%= scope_config.scope.assign_key %>` available if they use the `:browser` pipeline.


  ## Authentication routes

  <%= if not live? do %>scope <%= router_scope %> do
    pipe_through [:browser, :redirect_if_<%= schema.singular %>_is_authenticated]

    get "/<%= schema.plural %>/register", <%= inspect schema.alias %>RegistrationController, :new
    post "/<%= schema.plural %>/register", <%= inspect schema.alias %>RegistrationController, :create
  end

  <% end %>scope <%= router_scope %> do
    pipe_through [:browser, :require_authenticated_<%= schema.singular %>]<%= if live? do %>

    live_session :require_authenticated_<%= schema.singular %>,
      on_mount: [{<%= inspect auth_module %>, :require_authenticated}] do
      live "/<%= schema.plural %>/settings", <%= inspect schema.alias %>Live.Settings, :edit
      live "/<%= schema.plural %>/settings/confirm-email/:token", <%= inspect schema.alias %>Live.Settings, :confirm_email
    end

    post "/<%= schema.plural %>/update-password", <%= inspect schema.alias %>SessionController, :update_password<% else %>

    get "/<%= schema.plural %>/settings", <%= inspect schema.alias %>SettingsController, :edit
    put "/<%= schema.plural %>/settings", <%= inspect schema.alias %>SettingsController, :update
    get "/<%= schema.plural %>/settings/confirm-email/:token", <%= inspect schema.alias %>SettingsController, :confirm_email<% end %>
  end

  scope <%= router_scope %> do
    pipe_through [:browser]

    <%= if live? do %>live_session :current_<%= schema.singular %>,
      on_mount: [{<%= inspect auth_module %>, :mount_<%= scope_config.scope.assign_key %>}] do
      live "/<%= schema.plural %>/register", <%= inspect schema.alias %>Live.Registration, :new
      live "/<%= schema.plural %>/log-in", <%= inspect schema.alias %>Live.Login, :new
      live "/<%= schema.plural %>/log-in/:token", <%= inspect schema.alias %>Live.Confirmation, :new
    end

    post "/<%= schema.plural %>/log-in", <%= inspect schema.alias %>SessionController, :create
    delete "/<%= schema.plural %>/log-out", <%= inspect schema.alias %>SessionController, :delete<% else %>get "/<%= schema.plural %>/log-in", <%= inspect schema.alias %>SessionController, :new
    get "/<%= schema.plural %>/log-in/:token", <%= inspect schema.alias %>SessionController, :confirm
    post "/<%= schema.plural %>/log-in", <%= inspect schema.alias %>SessionController, :create
    delete "/<%= schema.plural %>/log-out", <%= inspect schema.alias %>SessionController, :delete<% end %>
  end

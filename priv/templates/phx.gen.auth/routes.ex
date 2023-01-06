
  ## Authentication routes

  scope <%= router_scope %> do
    pipe_through [:browser, :redirect_if_<%= schema.singular %>_is_authenticated]<%= if live? do %>

    live_session :redirect_if_<%= schema.singular %>_is_authenticated,
      on_mount: [{<%= inspect auth_module %>, :redirect_if_<%= schema.singular %>_is_authenticated}] do
      live "/<%= schema.plural %>/register", <%= inspect schema.alias %>RegistrationLive, :new
      live "/<%= schema.plural %>/log_in", <%= inspect schema.alias %>LoginLive, :new
      live "/<%= schema.plural %>/reset_password", <%= inspect schema.alias %>ForgotPasswordLive, :new
      live "/<%= schema.plural %>/reset_password/:token", <%= inspect schema.alias %>ResetPasswordLive, :edit
    end

    post "/<%= schema.plural %>/log_in", <%= inspect schema.alias %>SessionController, :create<% else %>

    get "/<%= schema.plural %>/register", <%= inspect schema.alias %>RegistrationController, :new
    post "/<%= schema.plural %>/register", <%= inspect schema.alias %>RegistrationController, :create
    get "/<%= schema.plural %>/log_in", <%= inspect schema.alias %>SessionController, :new
    post "/<%= schema.plural %>/log_in", <%= inspect schema.alias %>SessionController, :create
    get "/<%= schema.plural %>/reset_password", <%= inspect schema.alias %>ResetPasswordController, :new
    post "/<%= schema.plural %>/reset_password", <%= inspect schema.alias %>ResetPasswordController, :create
    get "/<%= schema.plural %>/reset_password/:token", <%= inspect schema.alias %>ResetPasswordController, :edit
    put "/<%= schema.plural %>/reset_password/:token", <%= inspect schema.alias %>ResetPasswordController, :update<% end %>
  end

  scope <%= router_scope %> do
    pipe_through [:browser, :require_authenticated_<%= schema.singular %>]<%= if live? do %>

    live_session :require_authenticated_<%= schema.singular %>,
      on_mount: [{<%= inspect auth_module %>, :ensure_authenticated}] do
      live "/<%= schema.plural %>/settings", <%= inspect schema.alias %>SettingsLive, :edit
      live "/<%= schema.plural %>/settings/confirm_email/:token", <%= inspect schema.alias %>SettingsLive, :confirm_email
    end<% else %>

    get "/<%= schema.plural %>/settings", <%= inspect schema.alias %>SettingsController, :edit
    put "/<%= schema.plural %>/settings", <%= inspect schema.alias %>SettingsController, :update
    get "/<%= schema.plural %>/settings/confirm_email/:token", <%= inspect schema.alias %>SettingsController, :confirm_email<% end %>
  end

  scope <%= router_scope %> do
    pipe_through [:browser]

    delete "/<%= schema.plural %>/log_out", <%= inspect schema.alias %>SessionController, :delete<%= if live? do %>

    live_session :current_<%= schema.singular %>,
      on_mount: [{<%= inspect auth_module %>, :mount_current_<%= schema.singular %>}] do
      live "/<%= schema.plural %>/confirm/:token", <%= inspect schema.alias %>ConfirmationLive, :edit
      live "/<%= schema.plural %>/confirm", <%= inspect schema.alias %>ConfirmationInstructionsLive, :new
    end<% else %>
    get "/<%= schema.plural %>/confirm", <%= inspect schema.alias %>ConfirmationController, :new
    post "/<%= schema.plural %>/confirm", <%= inspect schema.alias %>ConfirmationController, :create
    get "/<%= schema.plural %>/confirm/:token", <%= inspect schema.alias %>ConfirmationController, :edit
    post "/<%= schema.plural %>/confirm/:token", <%= inspect schema.alias %>ConfirmationController, :update<% end %>
  end

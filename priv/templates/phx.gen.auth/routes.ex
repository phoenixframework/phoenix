
  ## Authentication routes

  scope <%= router_scope %> do
    pipe_through [:browser, :redirect_if_<%= schema.singular %>_is_authenticated]

    get "/<%= schema.plural %>/register", <%= inspect schema.alias %>RegistrationController, :new
    post "/<%= schema.plural %>/register", <%= inspect schema.alias %>RegistrationController, :create
    get "/<%= schema.plural %>/log_in", <%= inspect schema.alias %>SessionController, :new
    post "/<%= schema.plural %>/log_in", <%= inspect schema.alias %>SessionController, :create
    get "/<%= schema.plural %>/reset_password", <%= inspect schema.alias %>ResetPasswordController, :new
    post "/<%= schema.plural %>/reset_password", <%= inspect schema.alias %>ResetPasswordController, :create
    get "/<%= schema.plural %>/reset_password/:token", <%= inspect schema.alias %>ResetPasswordController, :edit
    put "/<%= schema.plural %>/reset_password/:token", <%= inspect schema.alias %>ResetPasswordController, :update
  end

  scope <%= router_scope %> do
    pipe_through [:browser, :require_authenticated_<%= schema.singular %>]

    get "/<%= schema.plural %>/settings", <%= inspect schema.alias %>SettingsController, :edit
    put "/<%= schema.plural %>/settings", <%= inspect schema.alias %>SettingsController, :update
    get "/<%= schema.plural %>/settings/confirm_email/:token", <%= inspect schema.alias %>SettingsController, :confirm_email
  end

  scope <%= router_scope %> do
    pipe_through [:browser]

    delete "/<%= schema.plural %>/log_out", <%= inspect schema.alias %>SessionController, :delete
    get "/<%= schema.plural %>/confirm", <%= inspect schema.alias %>ConfirmationController, :new
    post "/<%= schema.plural %>/confirm", <%= inspect schema.alias %>ConfirmationController, :create
    get "/<%= schema.plural %>/confirm/:token", <%= inspect schema.alias %>ConfirmationController, :edit
    post "/<%= schema.plural %>/confirm/:token", <%= inspect schema.alias %>ConfirmationController, :update
  end

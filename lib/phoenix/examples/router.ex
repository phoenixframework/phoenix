defmodule AppRouter do
  use Phoenix.Router, port: 4000

  # get "users/:user_id/comments/:id", UsersController, :show
  get "pages/:page", PagesController, :show
  resources "users", UsersController
  resources "users/:user_id/comments", CommentsController
  # resources "pages", PagesController
end


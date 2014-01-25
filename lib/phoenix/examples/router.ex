defmodule Router do
  use Phoenix.Router, port: 4000

  get "pages/:page", PagesController, :show, as: :page
  get "files/*path", FilesController, :show
  get "profiles/user-:id", UsersController, :show
  resources "users", UsersController
  resources "users/:user_id/comments", CommentsController
end



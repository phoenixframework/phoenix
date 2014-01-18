defmodule AppRouter do
  use Phoenix.Router, port: 4000

  get "users/:user_id/comments/:id", :comments, :show
  get "pages/:page", :pages, :show
end

AppRouter.start

defmodule Router do
  use Phoenix.Router, port: 4000

  get "pages/:page", PagesController, :show, as: :page
  get "files/*path", FilesController, :show
  get "profiles/user-:id", UsersController, :show

  resources "users", UsersController do
    resources "posts", PostsController do
      resources "images", ImagesController
    end
  end
end



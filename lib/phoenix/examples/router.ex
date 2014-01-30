defmodule Router do
  use Phoenix.Router, port: 4000

  # get "pages/:page", PagesController, :show, as: :page
  # get "files/*path", FilesController, :show
  # get "profiles/user-:id", UsersController, :show
  resources "users", UsersController do
    get "reports/:name", PagesController, :show, as: :report
    resources "posts", PostsController do
      resources "images", ImagesController
    end
  end
  resources "comments", CommentsController
  resources "profiles", CommentsController do
    get ":user", UsersController, :show
  end
end



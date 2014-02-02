defmodule Router do
  use Phoenix.Router, port: 4000

  get "pages/:page", Phoenix.Controllers.Pages, :show, as: :page
  get "files/*path", Phoenix.Controllers.Files, :show, as: :file
  get "profiles/user-:id", Phoenix.Controllers.Users, :show

  resources "users", Phoenix.Controllers.Users do
    resources "comments", Phoenix.Controllers.Comments
  end
end

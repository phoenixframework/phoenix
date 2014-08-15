defmodule Phoenix.Router.ConsoleFormatterTest do
  use ExUnit.Case
  alias Phoenix.Router.ConsoleFormatter

  defmodule RouterTestSingleRoutes do
    use Phoenix.Router

    get "/", Phoenix.Controllers.Pages, :index, as: :page
    post "/images", Phoenix.Controllers.Images, :upload, as: :upload_image
    delete "/images", Phoenix.Controllers.Images, :destroy, as: :remove_image
  end

  test "format multiple routes" do
    assert draw(RouterTestSingleRoutes) == ["        page_path  GET     /        Pages.index/2",
                                            "upload_image_path  POST    /images  Images.upload/2",
                                            "remove_image_path  DELETE  /images  Images.destroy/2"]
  end

  defmodule RouterTestResources do
    use Phoenix.Router

    resources "images", Phoenix.Controllers.Images
  end

  test "format resource routes" do
    assert draw(RouterTestResources) == [
      "images_path  GET     /images           Images.index/2",
      "images_path  GET     /images/:id/edit  Images.edit/2",
      "images_path  GET     /images/new       Images.new/2",
      "images_path  GET     /images/:id       Images.show/2",
      "images_path  POST    /images           Images.create/2",
      "             PUT     /images/:id       Images.update/2",
      "             PATCH   /images/:id       Images.update/2",
      "images_path  DELETE  /images/:id       Images.destroy/2"
    ]
  end

  defp draw(router) do
    ConsoleFormatter.format_routes(router.__routes__)
  end
end


defmodule Phoenix.Router.ConsoleFormatterTest do
  use ExUnit.Case, async: true
  alias Phoenix.Router.ConsoleFormatter

  defmodule RouterTestSingleRoutes do
    use Phoenix.Router

    get "/", Phoenix.PageController, :index, as: :page
    post "/images", Phoenix.ImageController, :upload, as: :upload_image
    delete "/images", Phoenix.ImageController, :destroy, as: :remove_image
  end

  test "format multiple routes" do
    assert draw(RouterTestSingleRoutes) == """
            page_path  GET     /        Phoenix.PageController.index/2
    upload_image_path  POST    /images  Phoenix.ImageController.upload/2
    remove_image_path  DELETE  /images  Phoenix.ImageController.destroy/2
    """
  end

  defmodule RouterTestResources do
    use Phoenix.Router
    resources "/images", Phoenix.ImageController
  end

  test "format resource routes" do
    assert draw(RouterTestResources) == """
    image_path  GET     /images           Phoenix.ImageController.index/2
    image_path  GET     /images/:id/edit  Phoenix.ImageController.edit/2
    image_path  GET     /images/new       Phoenix.ImageController.new/2
    image_path  GET     /images/:id       Phoenix.ImageController.show/2
    image_path  POST    /images           Phoenix.ImageController.create/2
    image_path  PATCH   /images/:id       Phoenix.ImageController.update/2
                PUT     /images/:id       Phoenix.ImageController.update/2
    image_path  DELETE  /images/:id       Phoenix.ImageController.destroy/2
    """
  end

  defp draw(router) do
    ConsoleFormatter.format(router)
  end
end


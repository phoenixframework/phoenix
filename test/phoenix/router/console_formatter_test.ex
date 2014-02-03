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
    assert draw(RouterTestSingleRoutes) == ["        page  GET     /        Pages#index",
                                            "upload_image  POST    /images  Images#upload",
                                            "remove_image  DELETE  /images  Images#destroy"]
  end

  defmodule RouterTestResources do
    use Phoenix.Router

    resources "images", Phoenix.Controllers.Images
  end

  test "format resource routes" do
    assert draw(RouterTestResources) == ["  GET     images/:id  Images#show",
                                         "  GET     images/new  Images#new",
                                         "  GET     images      Images#index",
                                         "  POST    images      Images#create",
                                         "  PUT     images/:id  Images#update",
                                         "  PATCH   images/:id  Images#update",
                                         "  DELETE  images/:id  Images#destroy"]
  end

  defp draw(router) do
    ConsoleFormatter.format_routes(router.__routes__)
  end
end


defmodule Phoenix.HTML.Controller do
  @moduledoc """
  Imports the following functions from `Phoenix.Controller`
  into your views:

    * `Phoenix.Controller.get_flash/2`
    * `Phoenix.Controller.action_name/1`
    * `Phoenix.Controller.router_module/1`
    * `Phoenix.Controller.controller_module/1`

  """

  @doc false
  defmacro __using__(_) do
    quote do
      import Phoenix.Controller,
        only: [get_flash: 2, action_name: 1,
               router_module: 1, controller_module: 1]
    end
  end
end

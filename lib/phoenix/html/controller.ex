defmodule Phoenix.HTML.Controller do
  @moduledoc """
  Imports functions from `Phoenix.Controller` when used.

  It imports:

    * `Phoenix.Controller.get_flash/2`
    * `Phoenix.Controller.action_name/1`
    * `Phoenix.Controller.router_module/1`
    * `Phoenix.Controller.controller_module/1`
    * `Phoenix.Controller.get_csrf_token/0`
    * `Phoenix.Controller.delete_csrf_token/0`

  """

  @doc false
  defmacro __using__(_) do
    quote do
      import Phoenix.Controller,
        only: [get_flash: 2, action_name: 1,
               router_module: 1, controller_module: 1,
               get_csrf_token: 0, delete_csrf_token: 0]
    end
  end
end

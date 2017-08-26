defmodule Phoenix.Controller.ConnCase do
  @moduledoc """
  This module defines the test case that:

    * Runs concurrenty with other test cases.
    * Uses convenience methods for testing routers and controllers.
    * Uses functions from Phoenix.Controller, and
    * Disables logger.
  """

  defmacro __using__(_) do
    quote do
      use ExUnit.Case, async: true
      use RouterHelper
      import Phoenix.Controller

      setup do
        Logger.disable(self())
        :ok
      end
    end
  end
end

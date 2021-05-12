defmodule <%= inspect context.module %>.<%= inspect schema.alias %>Notifier do
  # For simplicity, this module simply logs messages to the terminal.
  # You should replace it by a proper email or notification tool, such as:
  #
  #   * Swoosh - https://hexdocs.pm/swoosh
  #   * Bamboo - https://hexdocs.pm/bamboo
  #
  defp deliver(to, body) do
    require Logger
    Logger.debug(body)
    {:ok, %{to: to, body: body}}
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(<%= schema.singular %>, url) do
    deliver(<%= schema.singular %>.email, """

    ==============================

    Hi #{<%= schema.singular %>.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to reset a <%= schema.singular %> password.
  """
  def deliver_reset_password_instructions(<%= schema.singular %>, url) do
    deliver(<%= schema.singular %>.email, """

    ==============================

    Hi #{<%= schema.singular %>.email},

    You can reset your password by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to update a <%= schema.singular %> email.
  """
  def deliver_update_email_instructions(<%= schema.singular %>, url) do
    deliver(<%= schema.singular %>.email, """

    ==============================

    Hi #{<%= schema.singular %>.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end
end

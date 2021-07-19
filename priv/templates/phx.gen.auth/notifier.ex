defmodule <%= inspect context.module %>.<%= inspect schema.alias %>Notifier do
  import Swoosh.Email

  alias <%= inspect context.base_module %>.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"MyApp", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(<%= schema.singular %>, url) do
    deliver(<%= schema.singular %>.email, "Confirmation instructions", """

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
    deliver(<%= schema.singular %>.email, "Reset password instructions", """

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
    deliver(<%= schema.singular %>.email, "Update email instructions", """

    ==============================

    Hi #{<%= schema.singular %>.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end
end

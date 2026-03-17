defmodule <%= inspect context.module %>.<%= inspect schema.alias %>Notifier do
  import Swoosh.Email

  alias <%= inspect context.base_module %>.Mailer
  alias <%= inspect context.module %>.<%= inspect schema.alias %>

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"<%= inspect context.base_module %>", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
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

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(<%= schema.singular %>, url) do
    case <%= schema.singular %> do
      %<%= inspect schema.alias %>{confirmed_at: nil} -> deliver_confirmation_instructions(<%= schema.singular %>, url)
      _ -> deliver_magic_link_instructions(<%= schema.singular %>, url)
    end
  end

  defp deliver_magic_link_instructions(<%= schema.singular %>, url) do
    deliver(<%= schema.singular %>.email, "Log in instructions", """

    ==============================

    Hi #{<%= schema.singular %>.email},

    You can log into your account by visiting the URL below:

    #{url}

    If you didn't request this email, please ignore this.

    ==============================
    """)
  end

  defp deliver_confirmation_instructions(<%= schema.singular %>, url) do
    deliver(<%= schema.singular %>.email, "Confirmation instructions", """

    ==============================

    Hi #{<%= schema.singular %>.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end
end

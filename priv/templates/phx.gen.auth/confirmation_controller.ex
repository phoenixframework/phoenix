defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>ConfirmationController do
  use <%= inspect context.web_module %>, :controller

  alias <%= inspect context.module %>

  def new(conn, _params) do
    render(conn, :new)
  end

  def create(conn, %{"<%= schema.singular %>" => %{"email" => email}}) do
    if <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>_by_email(email) do
      <%= inspect context.alias %>.deliver_<%= schema.singular %>_confirmation_instructions(
        <%= schema.singular %>,
        &url(~p"<%= schema.route_prefix %>/confirm/#{&1}")
      )
    end

    conn
    |> put_flash(
      :info,
      "If your email is in our system and it has not been confirmed yet, " <>
        "you will receive an email with instructions shortly."
    )
    |> redirect(to: ~p"/")
  end

  def edit(conn, %{"token" => token}) do
    render(conn, :edit, token: token)
  end

  # Do not log in the <%= schema.singular %> after confirmation to avoid a
  # leaked token giving the <%= schema.singular %> access to the account.
  def update(conn, %{"token" => token}) do
    case <%= inspect context.alias %>.confirm_<%= schema.singular %>(token) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "<%= schema.human_singular %> confirmed successfully.")
        |> redirect(to: ~p"/")

      :error ->
        # If there is a current <%= schema.singular %> and the account was already confirmed,
        # then odds are that the confirmation link was already visited, either
        # by some automation or by the <%= schema.singular %> themselves, so we redirect without
        # a warning message.
        case conn.assigns do
          %{current_<%= schema.singular %>: %{confirmed_at: confirmed_at}} when not is_nil(confirmed_at) ->
            redirect(conn, to: ~p"/")

          %{} ->
            conn
            |> put_flash(:error, "<%= schema.human_singular %> confirmation link is invalid or it has expired.")
            |> redirect(to: ~p"/")
        end
    end
  end
end

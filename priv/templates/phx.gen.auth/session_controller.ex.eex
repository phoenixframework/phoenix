defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>SessionController do
  use <%= inspect context.web_module %>, :controller

  alias <%= inspect context.module %>
  alias <%= inspect auth_module %><%= if live? do %>

  def create(conn, %{"_action" => "confirmed"} = params) do
    create(conn, params, "<%= schema.human_singular %> confirmed successfully.")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  # magic link login
  defp create(conn, %{"<%= schema.singular %>" => %{"token" => token} = <%= schema.singular %>_params}, info) do
    case <%= inspect context.alias %>.login_<%= schema.singular %>_by_magic_link(token) do
      {:ok, {<%= schema.singular %>, tokens_to_disconnect}} ->
        <%= inspect schema.alias %>Auth.disconnect_sessions(tokens_to_disconnect)

        conn
        |> put_flash(:info, info)
        |> <%= inspect schema.alias %>Auth.log_in_<%= schema.singular %>(<%= schema.singular %>, <%= schema.singular %>_params)

      _ ->
        conn
        |> put_flash(:error, "The link is invalid or it has expired.")
        |> redirect(to: ~p"<%= schema.route_prefix %>/log-in")
    end
  end

  # email + password login
  defp create(conn, %{"<%= schema.singular %>" => <%= schema.singular %>_params}, info) do
    %{"email" => email, "password" => password} = <%= schema.singular %>_params

    if <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, info)
      |> <%= inspect schema.alias %>Auth.log_in_<%= schema.singular %>(<%= schema.singular %>, <%= schema.singular %>_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"<%= schema.route_prefix %>/log-in")
    end
  end

  def update_password(conn, %{"<%= schema.singular %>" => <%= schema.singular %>_params} = params) do
    <%= schema.singular %> = conn.assigns.<%= scope_config.scope.assign_key %>.<%= schema.singular %>
    true = <%= inspect context.alias %>.sudo_mode?(<%= schema.singular %>)
    {:ok, {_<%= schema.singular %>, expired_tokens}} = <%= inspect context.alias %>.update_<%= schema.singular %>_password(<%= schema.singular %>, <%= schema.singular %>_params)

    # disconnect all existing LiveViews with old sessions
    <%= inspect schema.alias %>Auth.disconnect_sessions(expired_tokens)

    conn
    |> put_session(:<%= schema.singular %>_return_to, ~p"<%= schema.route_prefix %>/settings")
    |> create(params, "Password updated successfully!")
  end<% else %>

  def new(conn, _params) do
    email = get_in(conn.assigns, [:<%= scope_config.scope.assign_key %>, Access.key(:<%= schema.singular %>), Access.key(:email)])
    form = Phoenix.Component.to_form(%{"email" => email}, as: "<%= schema.singular %>")

    render(conn, :new, form: form)
  end

  # magic link login
  def create(conn, %{"<%= schema.singular %>" => %{"token" => token} = <%= schema.singular %>_params} = params) do
    info =
      case params do
        %{"_action" => "confirmed"} -> "<%= schema.human_singular %> confirmed successfully."
        _ -> "Welcome back!"
      end

    case <%= inspect context.alias %>.login_<%= schema.singular %>_by_magic_link(token) do
      {:ok, {<%= schema.singular %>, _expired_tokens}} ->
        conn
        |> put_flash(:info, info)
        |> <%= inspect schema.alias %>Auth.log_in_<%= schema.singular %>(<%= schema.singular %>, <%= schema.singular %>_params)

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "The link is invalid or it has expired.")
        |> render(:new, form: Phoenix.Component.to_form(%{}, as: "<%= schema.singular %>"))
    end
  end

  # email + password login
  def create(conn, %{"<%= schema.singular %>" => %{"email" => email, "password" => password} = <%= schema.singular %>_params}) do
    if <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, "Welcome back!")
      |> <%= inspect schema.alias %>Auth.log_in_<%= schema.singular %>(<%= schema.singular %>, <%= schema.singular %>_params)
    else
      form = Phoenix.Component.to_form(<%= schema.singular %>_params, as: "<%= schema.singular %>")

      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> render(:new, form: form)
    end
  end

  # magic link request
  def create(conn, %{"<%= schema.singular %>" => %{"email" => email}}) do
    if <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>_by_email(email) do
      <%= inspect context.alias %>.deliver_login_instructions(
        <%= schema.singular %>,
        &url(~p"<%= schema.route_prefix %>/log-in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    conn
    |> put_flash(:info, info)
    |> redirect(to: ~p"<%= schema.route_prefix %>/log-in")
  end

  def confirm(conn, %{"token" => token}) do
    if <%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>_by_magic_link_token(token) do
      form = Phoenix.Component.to_form(%{"token" => token}, as: "<%= schema.singular %>")

      conn
      |> assign(:<%= schema.singular %>, <%= schema.singular %>)
      |> assign(:form, form)
      |> render(:confirm)
    else
      conn
      |> put_flash(:error, "Magic link is invalid or it has expired.")
      |> redirect(to: ~p"<%= schema.route_prefix %>/log-in")
    end
  end<% end %>

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> <%= inspect schema.alias %>Auth.log_out_<%= schema.singular %>()
  end
end

defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>RegistrationController do
  use <%= inspect context.web_module %>, :controller

  alias <%= inspect context.module %>
  alias <%= inspect schema.module %>

  def new(conn, _params) do
    changeset = <%= inspect context.alias %>.change_<%= schema.singular %>_email(%<%= inspect schema.alias %>{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"<%= schema.singular %>" => <%= schema.singular %>_params}) do
    case <%= inspect context.alias %>.register_<%= schema.singular %>(<%= schema.singular %>_params) do
      {:ok, <%= schema.singular %>} ->
        {:ok, _} =
          <%= inspect context.alias %>.deliver_login_instructions(
            <%= schema.singular %>,
            &url(~p"<%= schema.route_prefix %>/log-in/#{&1}")
          )

        conn
        |> put_flash(
          :info,
          "An email was sent to #{<%= schema.singular %>.email}, please access it to confirm your account."
        )
        |> redirect(to: ~p"<%= schema.route_prefix %>/log-in")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end
end

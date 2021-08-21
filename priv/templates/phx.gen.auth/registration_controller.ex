defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>RegistrationController do
  use <%= inspect context.web_module %>, :controller

  alias <%= inspect context.module %>
  alias <%= inspect schema.module %>
  alias <%= inspect auth_module %>

  def new(conn, _params) do
    changeset = <%= inspect context.alias %>.change_<%= schema.singular %>_registration(%<%= inspect schema.alias %>{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"<%= schema.singular %>" => <%= schema.singular %>_params}) do
    case <%= inspect context.alias %>.register_<%= schema.singular %>(<%= schema.singular %>_params) do
      {:ok, <%= schema.singular %>} ->
        {:ok, _} =
          <%= inspect context.alias %>.deliver_<%= schema.singular %>_confirmation_instructions(
            <%= schema.singular %>,
            &Routes.<%= schema.route_helper %>_confirmation_url(conn, :edit, &1)
          )

        conn
        |> put_flash(:info, "<%= schema.human_singular %> created successfully.")
        |> <%= inspect schema.alias %>Auth.log_in_<%= schema.singular %>(<%= schema.singular %>)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end
end

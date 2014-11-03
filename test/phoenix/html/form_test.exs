defmodule Phoenix.HTML.FormTest do
  use ExUnit.Case, async: true

  import Phoenix.HTML.Form

  defmodule FormView do
    require EEx
    import Phoenix.HTML.Form

    EEx.function_from_string :def, :render, """
    <%= form_for @user, [action: "/users", remote: true], fn f ->  %>
      <%= "Hey there" %>
      <%= text_field f, :id, value: nil %>
      <%= text_field f, :name %>
    <% end %>
    """, [:assigns]
  end

  defmodule User do
    defstruct id: nil, name: nil
  end

  test "form_tag" do
    assert form_tag([action: "/users"], do: "Hello") ==
      ~s(<form action="/users">Hello</form>)
  end

  test "rendered from EEx" do
    user = %User{id: 1, name: "José Valim"}
    view = FormView.render([user: user])
    assert view == ~S"""
    <form action="/users" data-remote="true" method="post">
      Hey there
      <input name="user[id]" type="text" value="" />
      <input name="user[name]" type="text" value="José Valim" />
    </form>
    """
  end
end


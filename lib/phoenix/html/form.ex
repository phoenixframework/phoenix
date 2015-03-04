defmodule Phoenix.HTML.Form do
  @moduledoc ~S"""
  Helpers related to producing HTML forms.

  The functions in this module can be used in three
  distinct scenario:

    * with model data - when information to populate
      the form comes from a model

    * with connection data - when a form is created based
      on the information in the connection (aka `Plug.Conn`)

    * without form data - when the functions are used directly,
      outside of a form

  We will explore all three scenarios below.

  ## With model data

  The entry point for defining forms in Phhoenix is with
  the `form_for/4` function. For this example, we will
  use `Ecto.Changeset`, which integrate nicely with Phoenix
  forms via the `phoenix_ecto` package.

  Imagine you have the following action in your controller:

      def new(conn, _params) do
        changeset = User.changeset(%User{})
        render conn, "new.html", changeset: changeset
      end

  where `User.changeset/2` is defined as follows:

      def changeset(user, params \\ nil) do
        cast(user, params)
      end

  Now a `@changeset` assign is available in views which we
  can pass to the form:

      <%= form_for @changeset, user_path(@conn, :create), fn f -> %>
        <label>
          Name: <%= text_input f, :name %>
        </label>

        <label>
          Age: <%= select f, :age, 18..100 %>
        </label>

        <%= submit "Submit" %>
      <% end %>

  `form_for/4` receives the `Ecto.Changeset` and converts it
  to a form, which is passed to the function as the argument
  `f`. All the remaining functions in this module receive
  the form and automatically generate the input fields, often
  by extracting information from the given changeset. For example,
  if the user had a default value for age set, it will
  automatically show up as selected in the form.

  ## With connection data

  `form_for/4` expects as first argument any data structure that
  implements the `Phoenix.HTML.FormData` protocol. By default,
  Phoenix implements this protocol for `Plug.Conn`, allowing us
  to create forms based only on connection information.

  This is useful when you are creating forms that are not backed
  by any kind of model data, like a search form.

      <%= form_for @conn, search_path(@conn, :new), [name: :search], fn f -> %>
        <%= text_input f, :for %>
        <%= submit "Search" %>
      <% end %>

  ## Without form data

  Sometimes we may want to generate a `text_input/3` or any other
  tag outside of a form. The functions in this module also support
  such usage by simply passing an atom as first argument instead
  of the form.

      <%= text_input :user, :name, value: "This is a prepopulated value" %>

  """

  alias Phoenix.HTML.Form
  import Phoenix.HTML
  import Phoenix.HTML.Tag

  @doc """
  Defines the Phoenix.HTML.Form struct.

  Its fields are:

    * `:name` - the name to be used when generating input fields
    * `:method` - the http method to be used by the form
    * `:model` - the model used to lookup field data
    * `:params` - the parameters associated to this form in case
      they were sent as part of a previous request
    * `:options` - a copy of the options given when creating the
      form via `form_for/4`
  """
  defstruct [:name, :method, :model, :params, :options]
  @type t :: %Form{name: String.t, method: String.t, model: map,
                   params: map, options: Keyword.t}

  @doc """
  Generates a form tag with a form builder.

  See the module documentation for examples of using this
  function. All options are passed to the underlying "form"
  tag. See `Phoenix.HTML.Tag.form_tag/1` for more information.
  """
  @spec form_for(Phoenix.HTML.FormData.t, String.t,
                 Keyword.t, (t -> Phoenix.HTML.unsafe)) :: Phoenix.HTML.safe
  def form_for(form_data, action, options \\ [], fun) when is_function(fun, 1) do
    form = Phoenix.HTML.FormData.to_form(form_data, options)

    options =
      form.options
      |> Keyword.put(:method, form.method)
      |> Keyword.put(:action, action)

    safe_concat [form_tag(options), fun.(form), safe("</form>")]
  end

  ## Form helpers

  @doc """
  Generates a text input.

  The form should either be a `Phoenix.HTML.Form` emitted
  by `form_for` or an atom.

  All given options are forwarded to the underlying input,
  default values are provided for id, name and value if
  possible.

  ## Examples

      # Assuming form contains a User model
      iex> text_input(form, :name)
      <input id="user_name" name="user[name]" type="text" value="">

      iex> text_input(:user, :name)
      <input id="user_name" name="user[name]" type="text" value="">

  """
  def text_input(form, field, opts \\ []) do
    generic_input(:text, form, field, opts)
  end

  @doc """
  Generates a hidden input.

  See `text_input/3` for example and docs.
  """
  def hidden_input(form, field, opts \\ []) do
    generic_input(:hidden, form, field, opts)
  end

  @doc """
  Generates an email input.

  See `text_input/3` for example and docs.
  """
  def email_input(form, field, opts \\ []) do
    generic_input(:email, form, field, opts)
  end

  @doc """
  Generates a number input.

  See `text_input/3` for example and docs.
  """
  def number_input(form, field, opts \\ []) do
    generic_input(:number, form, field, opts)
  end

  defp generic_input(type, form, field, opts) when is_atom(field) and is_list(opts) do
    opts =
      opts
      |> Keyword.put_new(:type, type)
      |> Keyword.put_new(:id, id_from(form, field))
      |> Keyword.put_new(:name, name_from(form, field))
      |> Keyword.put_new(:value, value_from(form, field))
    tag(:input, opts)
  end

  @doc """
  Generates a submit input to send the form.

  All options are forwarded to the underlying input tag.

  ## Examples

      iex> submit "Submit"
      <input type="submit" value="Submit">

  """
  def submit(value, opts \\ []) do
    opts =
      opts
      |> Keyword.put_new(:type, "submit")
      |> Keyword.put_new(:value, value)
    tag(:input, opts)
  end

  @doc """
  Generates a radio button.

  Invoke this function for each possible value you to be
  sent to the server.

  ## Examples

      # Assuming form contains a User model
      iex> radio_button(form, :role, "admin")
      <input id="user_role_admin" name="user[role]" type="radio" value="admin">

  ## Options

  All options are simply forwarded to the underlying HTML tag.
  """
  def radio_button(form, field, value, opts \\ []) do
    value = html_escape(value)

    opts =
      opts
      |> Keyword.put_new(:type, "radio")
      |> Keyword.put_new(:id, id_from(form, field) <> "_" <> elem(value, 1))
      |> Keyword.put_new(:name, name_from(form, field))

    if value == html_escape(value_from(form, field)) do
      opts = Keyword.put_new(opts, :checked, true)
    end

    tag(:input, [value: value] ++ opts)
  end

  @doc """
  Generates a checkbox.

  This function is useful for sending boolean values to the server.

  ## Examples

      # Assuming form contains a User model
      iex> checkbox(form, :famous)
      <input name="user[famous]" type="hidden" value="false">
      <input checked="checked" id="user_famous" name="user[famous]"> type="checkbox" value="true")

  ## Options

    * `:checked_value` - the value to be sent when the checkbox is checked.
      Defaults to "true"

    * `:unchecked_value` - the value to be sent then the checkbox is unchecked,
      Defaults to "false"

    * `:value` - the value used to check if a checkbox is checked or unchecked.
      The default value is extracted from the model if a model is available

  All other options are forwarded to the underlying HTML tag.

  ## Hidden fields

  Because an unchecked checkbox is not sent to the server, Phoenix
  automatically generates a hidden field with the unchecked_value
  *before* the checkbox field to ensure the `unchecked_value` is sent
  when the checkbox is not marked.
  """
  def checkbox(form, field, opts \\ []) do
    opts =
      opts
      |> Keyword.put_new(:type, "checkbox")
      |> Keyword.put_new(:id, id_from(form, field))
      |> Keyword.put_new(:name, name_from(form, field))

    {value, opts}           = Keyword.pop(opts, :value, value_from(form, field))
    {checked_value, opts}   = Keyword.pop(opts, :checked_value, true)
    {unchecked_value, opts} = Keyword.pop(opts, :unchecked_value, false)

    # We html escape all values to be sure we are comparing
    # apples to apples. After all we may have true in the model
    # but "true" in the params and both need to match.
    value           = html_escape(value)
    checked_value   = html_escape(checked_value)
    unchecked_value = html_escape(unchecked_value)

    if value == checked_value do
      opts = Keyword.put_new(opts, :checked, true)
    end

    safe_concat tag(:input, name: Keyword.get(opts, :name), type: "hidden", value: unchecked_value),
                tag(:input, [value: checked_value] ++ opts)
  end

  ## Helpers

  defp value_from(%{model: model, params: params}, field),
    do: Map.get(params, Atom.to_string(field)) || Map.get(model, field)
  defp value_from(name, _field) when is_atom(name),
    do: nil

  defp id_from(%{name: name}, field),
    do: "#{name}_#{field}"
  defp id_from(name, field) when is_atom(name),
    do: "#{name}_#{field}"

  defp name_from(%{name: name}, field),
    do: "#{name}[#{field}]"
  defp name_from(name, field) when is_atom(name),
    do: "#{name}[#{field}]"
end

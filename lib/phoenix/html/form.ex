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

  The entry point for defining forms in Phoenix is with
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

    * `:source` - the data structure given to `form_for/4` that
      implements the form data protocol

    * `:name` - the name to be used when generating input fields

    * `:model` - the model used to lookup field data

    * `:params` - the parameters associated to this form in case
      they were sent as part of a previous request

    * `:hidden` - a keyword list of fields that are required for
      submitting the form behind the scenes as hidden inputs. This
      information will be used by upcoming nested forms

    * `:options` - a copy of the options given when creating the
      form via `form_for/4` without any form data specific key

    * `:errors` - a keyword list of errors that associated with
      the form

    * `:validations` - a keyword list of validations for the given
      inputs
  """
  defstruct source: nil, name: nil, model: %{}, hidden: [], params: %{},
            errors: [], validations: [], options: []

  @type t :: %Form{source: term, name: String.t, model: %{atom => term},
                   params: %{binary => term}, hidden: Keyword.t, options: Keyword.t,
                   errors: Keyword.t, validations: Keyword.t}

  @doc """
  Converts an attribute/form field into its humanize version.

      iex> humanize(:username)
      "Username"
      iex> humanize(:created_at)
      "Created at"

  """
  def humanize(atom) when is_atom(atom),
    do: humanize(Atom.to_string(atom))
  def humanize(bin) when is_binary(bin),
    do: bin |> String.replace("_", " ") |> String.capitalize

  @doc """
  Generates a form tag with a form builder.

  See the module documentation for examples of using this function.

  ## Options

    * `:name` - the name to be used in the form. May be inflected
      if a model is available

    * `:method` - the HTTP method. If the method is not "get" nor "post",
      an input tag with name `_method` is generated along-side the form tag.
      Defaults to "post".

    * `:multipart` - when true, sets enctype to "multipart/form-data".
      Required when uploading files

    * `:csrf_token` - for "post" requests, the form tag will automatically
      include an input tag with name `_csrf_token`. When set to false, this
      is disabled

    * `:enforce_utf8` - when false, does not enforce utf8

  See `Phoenix.HTML.Tag.form_tag/2` for more information on the
  options above.
  """
  @spec form_for(Phoenix.HTML.FormData.t, String.t,
                 Keyword.t, (t -> Phoenix.HTML.unsafe)) :: Phoenix.HTML.safe
  def form_for(form_data, action, options \\ [], fun) when is_function(fun, 1) do
    form = Phoenix.HTML.FormData.to_form(form_data, options)
    safe_concat [form_tag(action, form.options), fun.(form), safe("</form>")]
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
      text_input(form, :name)
      #=> <input id="user_name" name="user[name]" type="text" value="">

      text_input(:user, :name)
      #=> <input id="user_name" name="user[name]" type="text" value="">

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

  @doc """
  Generates a password input.

  See `password_input/3` for example and docs.
  """
  def password_input(form, field, opts \\ []) do
    generic_input(:password, form, field, opts)
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
  Generates a textarea input.

  All given options are forwarded to the underlying input,
  default values are provided for id, name and textarea
  content if possible.

  ## Examples

      # Assuming form contains a User model
      textarea_input(form, :description)
      #=> <textarea id="user_description" name="user[description]"></textarea>

  ## New lines

  Notice the generated textarea includes a new line after
  the opening tag. This is because the HTML spec says new
  lines after tags must be ignored and all major browser
  implementations do that.

  So in order to avoid new lines provided by the user
  from being ignored when the form is resubmitted, we
  automatically add a new line before the text area
  value.
  """
  def textarea_input(form, field, opts \\ []) do
    opts =
      opts
      |> Keyword.put_new(:id, id_from(form, field))
      |> Keyword.put_new(:name, name_from(form, field))

    {value, opts} = Keyword.pop(opts, :value, value_from(form, field) || "")
    content_tag(:textarea, safe_concat("\n", value), opts)
  end

  @doc """
  Generates a file input.

  It requires the given form to be configured with `multipart: true`
  when invokig `form_for/4`, otherwise it fails with `ArgumentError`.

  See `text_input/3` for example and docs.
  """
  def file_input(form, field, opts \\ []) do
    if match?(%Form{}, form) and !form.options[:multipart] do
      raise ArgumentError, "file_input/3 requires the enclosing form_for/4 " <>
                           "to be configured with multipart: true"
    end

    opts =
      opts
      |> Keyword.put_new(:type, :file)
      |> Keyword.put_new(:id, id_from(form, field))
      |> Keyword.put_new(:name, name_from(form, field))

    tag(:input, opts)
  end

  @doc """
  Generates a submit input to send the form.

  All options are forwarded to the underlying input tag.

  ## Examples

      submit "Submit"
      #=> <input type="submit" value="Submit">

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
      radio_button(form, :role, "admin")
      #=> <input id="user_role_admin" name="user[role]" type="radio" value="admin">

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
      checkbox(form, :famous)
      #=> <input name="user[famous]" type="hidden" value="false">
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

  @doc """
  Generates a select tag with the given `values`.

  Values are expected to be an Enumerable containing two-item tuples
  (like maps and keyword lists) or any Enumerable where the element
  will be used both as key and value for the generated select.

  ## Examples

      # Assuming form contains a User model
      select(form, :age, 0..120)
      #=> <select id="user_age" name="user[age]">
          <option value="0">0</option>
          ...
          <option value="120">120</option>
          </select>

      select(form, :role, [admin: "Admin", user: "User"])
      #=> <select id="user_role" name="user[role]">
          <option value="admin">Admin</option>
          <option value="user">User</option>
          </select>

      select(form, :role, [admin: "Admin", user: "User"], prompt: "Choose your role")
      #=> <select id="user_role" name="user[role]">
          <option value="">Choose your role</option>
          <option value="admin">Admin</option>
          <option value="user">User</option>
          </select>

  ## Options

    * `:prompt` - an option to include at the top of the options with
      the given prompt text

    * `:value` - the value used to select a given option.
      The default value is extracted from the model if a model is available

    * `:default` - the default value to use when none was given in
      `:value` and none was available in the model

  All other options are forwarded to the underlying HTML tag.
  """
  def select(form, field, values, opts \\ []) do
    {default, opts} = Keyword.pop(opts, :default)
    {value, opts}   = Keyword.pop(opts, :value, value_from(form, field) || default)

    {options, opts} = case Keyword.pop(opts, :prompt) do
      {nil, opts}    -> {safe(""), opts}
      {prompt, opts} -> {content_tag(:option, prompt, value: ""), opts}
    end

    opts =
      opts
      |> Keyword.put_new(:id, id_from(form, field))
      |> Keyword.put_new(:name, name_from(form, field))

    options = options_for_select(values, options, html_escape(value))
    content_tag(:select, options, opts)
  end

  defp options_for_select(values, options, value) do
    Enum.reduce values, options, fn
      {option_value, option_key}, acc ->
        option_key   = html_escape(option_key)
        option_value = html_escape(option_value)
        option(option_key, option_value, value, acc)
      option, acc ->
        option = html_escape(option)
        option(option, option, value, acc)
    end
  end

  defp option(option_key, option_value, value, acc) do
    opts = [value: option_value, selected: value == option_value]
    safe_concat acc, content_tag(:option, option_key, opts)
  end

  ## Datetime

  @doc ~S"""
  Generates select tags for datetime.

  ## Examples

      # Assuming form contains a User model
      datetime_select form, :born_at
      #=> <select id="user_born_at_year" name="user[born_at][year]">...</select> /
          <select id="user_born_at_month" name="user[born_at][month]">...</select> /
          <select id="user_born_at_day" name="user[born_at][day]">...</select> —
          <select id="user_born_at_hour" name="user[born_at][hour]">...</select> :
          <select id="user_born_at_min" name="user[born_at][min]">...</select>

  If you want to include the seconds field (hidden by default), pass `sec: []`:

      # Assuming form contains a User model
      datetime_select form, :born_at, sec: []

  If you want to configure the years range:

      # Assuming form contains a User model
      datetime_select form, :born_at, year: [options: 1900..2100]

  You are also able to configure `:month`, `:day`, `:hour`, `:min` and
  `:sec`. All options given to those keys will be forwarded to the
  underlying select. See `select/4` for more information.

  ## Options

    * `:value` - the value used to select a given option.
      The default value is extracted from the model if a model is available

    * `:default` - the default value to use when none was given in
      `:value` and none was available in the model

    * `:year`, `:month`, `:day`, `:hour`, `:min`, `:sec` - options passed
      to the underlying select. See `select/4` for more information.
      The available values can be given in `:options`.

    * `:builder` - specify how the select can be build. It must be a function
      that receives a builder that should be invoked with the select name
      and a set of options. See builder below for more information.

  ## Builder

  The generated datetime_select can be customized at will by providing a
  builder option. Here is an example from EEx:

      <%= datetime_select form, :born_at, builder: fn b -> %>
        Date: <%= b.(:day, []) %> / <%= b.(:month, []) %> / <%= b.(:hour, []) %>
        Time: <%= b.(:hour, []) %> : <%= b.(:min, []) %>
      <% end %>

  Although we have passed empty lists as options (they are required), you
  could pass any option there and it would be given to the underlying select
  input.

  In practice, we recommend you to create your own helper with your default
  builder:

      def my_datetime_select(form, field, opts \\ []) do
        builder = fn b ->
          ~e"\""
          Date: <%= b.(:day, []) %> / <%= b.(:month, []) %> / <%= b.(:hour, []) %>
          Time: <%= b.(:hour, []) %> : <%= b.(:min, []) %>
          "\""
        end

        datetime_select(form, field, [builder: builder] ++ opts)
      end

  Then you are able to use your own datetime_select throughout your whole
  application.

  ## Supported date values

  The following values are supported as date:

    * a map containing the `year`, `month` and `day` keys (either as strings or atoms)
    * a tuple with three elements: `{year, month, day}`
    * `nil`

  ## Supported time values

  The following values are supported as time:

    * a map containing the `hour` and `min` keys and an optional `sec` key (either as strings or atoms)
    * a tuple with three elements: `{hour, min, sec}`
    * a tuple with four elements: `{hour, min, sec, usec}`
    * `nil`

  """
  def datetime_select(form, field, opts \\ []) do
    value = Keyword.get(opts, :value, value_from(form, field) || Keyword.get(opts, :default))

    builder =
      Keyword.get(opts, :builder) || fn b ->
        date = date_builder(b, opts)
        time = time_builder(b, opts)
        safe_concat [date, safe(" &mdash; "), time]
      end

    builder.(datetime_builder(form, field, date_value(value), time_value(value), opts))
  end

  @doc """
  Generates select tags for date.

  Check `datetime_select/3` for more information on options and supported values.
  """
  def date_select(form, field, opts \\ []) do
    value   = Keyword.get(opts, :value, value_from(form, field) || Keyword.get(opts, :default))
    builder = Keyword.get(opts, :builder) || &date_builder(&1, opts)
    builder.(datetime_builder(form, field, date_value(value), nil, opts))
  end

  defp date_builder(b, _opts) do
    safe_concat [b.(:year, []), safe(" / "), b.(:month, []), safe(" / "), b.(:day, [])]
  end

  defp date_value(%{"year" => year, "month" => month, "day" => day}),
    do: %{year: year, month: month, day: day}
  defp date_value(%{year: year, month: month, day: day}),
    do: %{year: year, month: month, day: day}

  defp date_value({{year, month, day}, _}),
    do: %{year: year, month: month, day: day}
  defp date_value({year, month, day}),
    do: %{year: year, month: month, day: day}

  defp date_value(nil),
    do: %{year: nil, month: nil, day: nil}
  defp date_value(other),
    do: raise(ArgumentError, "unrecognized date #{inspect other}")

  @doc """
  Generates select tags for time.

  Check `datetime_select/3` for more information on options and supported values.
  """
  def time_select(form, field, opts \\ []) do
    value   = Keyword.get(opts, :value, value_from(form, field) || Keyword.get(opts, :default))
    builder = Keyword.get(opts, :builder) || &time_builder(&1, opts)
    builder.(datetime_builder(form, field, nil, time_value(value), opts))
  end

  defp time_builder(b, opts) do
    time = safe_concat [b.(:hour, []), safe(" : "), b.(:min, [])]

    if Keyword.get(opts, :sec) do
      safe_concat [time, safe(" : "), b.(:sec, [])]
    else
      time
    end
  end

  defp time_value(%{"hour" => hour, "min" => min} = map),
    do: %{hour: hour, min: min, sec: Map.get(map, "sec", 0)}
  defp time_value(%{hour: hour, min: min} = map),
    do: %{hour: hour, min: min, sec: Map.get(map, :sec, 0)}

  defp time_value({_, {hour, min, sec, _msec}}),
    do: %{hour: hour, min: min, sec: sec}
  defp time_value({hour, min, sec, _mseg}),
    do: %{hour: hour, min: min, sec: sec}
  defp time_value({_, {hour, min, sec}}),
    do: %{hour: hour, min: min, sec: sec}
  defp time_value({hour, min, sec}),
    do: %{hour: hour, min: min, sec: sec}

  defp time_value(nil),
    do: %{hour: nil, min: nil, sec: nil}
  defp time_value(other),
    do: raise(ArgumentError, "unrecognized time #{inspect other}")

  @months %{
    "1"  => "January",
    "2"  => "February",
    "3"  => "March",
    "4"  => "April",
    "5"  => "May",
    "6"  => "June",
    "7"  => "July",
    "8"  => "August",
    "9"  => "September",
    "10" => "October",
    "11" => "November",
    "12" => "December"
  }

  map = &Enum.map(&1, fn i ->
    i = Integer.to_string(i)
    {i, String.rjust(i, 2, ?0)}
  end)

  @days   map.(1..31)
  @hours  map.(0..23)
  @minsec map.(0..59)

  defp datetime_builder(form, field, date, time, parent) do
    id   = Keyword.get(parent, :id, id_from(form, field))
    name = Keyword.get(parent, :name, name_from(form, field))

    fn
      :year, opts when date != nil ->
        {year, _, _}  = :erlang.date()
        {value, opts} = datetime_options(:year, year-5..year+5, id, name, parent, date, opts)
        select(:datetime, :year, value, opts)
      :month, opts when date != nil ->
        {value, opts} = datetime_options(:month, @months, id, name, parent, date, opts)
        select(:datetime, :month, value, opts)
      :day, opts when date != nil ->
        {value, opts} = datetime_options(:day, @days, id, name, parent, date, opts)
        select(:datetime, :day, value, opts)
      :hour, opts when time != nil ->
        {value, opts} = datetime_options(:hour, @hours, id, name, parent, time, opts)
        select(:datetime, :hour, value, opts)
      :min, opts when time != nil ->
        {value, opts} = datetime_options(:min, @minsec, id, name, parent, time, opts)
        select(:datetime, :min, value, opts)
      :sec, opts when time != nil ->
        {value, opts} = datetime_options(:sec, @minsec, id, name, parent, time, opts)
        select(:datetime, :sec, value, opts)
    end
  end

  defp datetime_options(type, values, id, name, parent, datetime, opts) do
    opts = Keyword.merge Keyword.get(parent, type, []), opts
    suff = Atom.to_string(type)

    {value, opts} = Keyword.pop(opts, :options, values)

    {value,
      opts
      |> Keyword.put_new(:id, id <> "_" <> suff)
      |> Keyword.put_new(:name, name <> "[" <> suff <> "]")
      |> Keyword.put_new(:value, Map.get(datetime, type))}
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

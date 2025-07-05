defmodule <%= inspect schema.module %> do
  use Ecto.Schema
  import Ecto.Changeset
<%= if schema.binary_id do %>
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id<% end %>
  schema <%= inspect schema.table %> do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, <%= inspect schema.timestamp_type %>
    field :authenticated_at, <%= inspect schema.timestamp_type %>, virtual: true

    timestamps(<%= if schema.timestamp_type != :naive_datetime, do: "type: #{inspect schema.timestamp_type}" %>)
  end

  @doc """
  A <%= schema.singular %> changeset for registering or changing the email.

  It requires the email to change otherwise an error is added.

  ## Options

    * `:validate_unique` - Set to false if you don't want to validate the
      uniqueness of the email, useful when displaying live validations.
      Defaults to `true`.
  """
  def email_changeset(<%= schema.singular %>, attrs, opts \\ []) do
    <%= schema.singular %>
    |> cast(attrs, [:email])
    |> validate_email(opts)
  end

  defp validate_email(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:email])
      |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
        message: "must have the @ sign and no spaces"
      )
      |> validate_length(:email, max: 160)

    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unsafe_validate_unique(:email, <%= inspect schema.repo %>)
      |> unique_constraint(:email)
      |> validate_email_changed()
    else
      changeset
    end
  end

  defp validate_email_changed(changeset) do
    if get_field(changeset, :email) && get_change(changeset, :email) == nil do
      add_error(changeset, :email, "did not change")
    else
      changeset
    end
  end

  @doc """
  A <%= schema.singular %> changeset for changing the password.

  It is important to validate the length of the password, as long passwords may
  be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(<%= schema.singular %>, attrs, opts \\ []) do
    <%= schema.singular %>
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    # Examples of additional password validation:
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset<%= if hashing_library.name == :bcrypt do %>
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)<% end %>
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, <%= inspect hashing_library.module %>.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(<%= schema.singular %>) do
    <%= case schema.timestamp_type do %>
    <% :naive_datetime -> %>now = NaiveDateTime.utc_now(:second)
    <% :utc_datetime -> %>now = DateTime.utc_now(:second)
    <% :utc_datetime_usec -> %>now = DateTime.utc_now(:microsecond)
    <% end %>change(<%= schema.singular %>, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no <%= schema.singular %> or the <%= schema.singular %> doesn't have a password, we call
  `<%= inspect hashing_library.module %>.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%<%= inspect schema.module %>{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    <%= inspect hashing_library.module %>.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    <%= inspect hashing_library.module %>.no_user_verify()
    false
  end
end

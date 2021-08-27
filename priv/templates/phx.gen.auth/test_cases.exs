  import <%= inspect context.module %>Fixtures
  alias <%= inspect context.module %>.{<%= inspect schema.alias %>, <%= inspect schema.alias %>Token}

  describe "get_<%= schema.singular %>_by_email/1" do
    test "does not return the <%= schema.singular %> if the email does not exist" do
      refute <%= inspect context.alias %>.get_<%= schema.singular %>_by_email("unknown@example.com")
    end

    test "returns the <%= schema.singular %> if the email exists" do
      %{id: id} = <%= schema.singular %> = <%= schema.singular %>_fixture()
      assert %<%= inspect schema.alias %>{id: ^id} = <%= inspect context.alias %>.get_<%= schema.singular %>_by_email(<%= schema.singular %>.email)
    end
  end

  describe "get_<%= schema.singular %>_by_email_and_password/2" do
    test "does not return the <%= schema.singular %> if the email does not exist" do
      refute <%= inspect context.alias %>.get_<%= schema.singular %>_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the <%= schema.singular %> if the password is not valid" do
      <%= schema.singular %> = <%= schema.singular %>_fixture()
      refute <%= inspect context.alias %>.get_<%= schema.singular %>_by_email_and_password(<%= schema.singular %>.email, "invalid")
    end

    test "returns the <%= schema.singular %> if the email and password are valid" do
      %{id: id} = <%= schema.singular %> = <%= schema.singular %>_fixture()

      assert %<%= inspect schema.alias %>{id: ^id} =
               <%= inspect context.alias %>.get_<%= schema.singular %>_by_email_and_password(<%= schema.singular %>.email, valid_<%= schema.singular %>_password())
    end
  end

  describe "get_<%= schema.singular %>!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= inspect schema.sample_id %>)
      end
    end

    test "returns the <%= schema.singular %> with the given id" do
      %{id: id} = <%= schema.singular %> = <%= schema.singular %>_fixture()
      assert %<%= inspect schema.alias %>{id: ^id} = <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= schema.singular %>.id)
    end
  end

  describe "register_<%= schema.singular %>/1" do
    test "requires email and password to be set" do
      {:error, changeset} = <%= inspect context.alias %>.register_<%= schema.singular %>(%{})

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email and password when given" do
      {:error, changeset} = <%= inspect context.alias %>.register_<%= schema.singular %>(%{email: "not valid", password: "not valid"})

      assert %{
               email: ["must have the @ sign and no spaces"],
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for email and password for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = <%= inspect context.alias %>.register_<%= schema.singular %>(%{email: too_long, password: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      %{email: email} = <%= schema.singular %>_fixture()
      {:error, changeset} = <%= inspect context.alias %>.register_<%= schema.singular %>(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = <%= inspect context.alias %>.register_<%= schema.singular %>(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers <%= schema.plural %> with a hashed password" do
      email = unique_<%= schema.singular %>_email()
      {:ok, <%= schema.singular %>} = <%= inspect context.alias %>.register_<%= schema.singular %>(valid_<%= schema.singular %>_attributes(email: email))
      assert <%= schema.singular %>.email == email
      assert is_binary(<%= schema.singular %>.hashed_password)
      assert is_nil(<%= schema.singular %>.confirmed_at)
      assert is_nil(<%= schema.singular %>.password)
    end
  end

  describe "change_<%= schema.singular %>_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = <%= inspect context.alias %>.change_<%= schema.singular %>_registration(%<%= inspect schema.alias %>{})
      assert changeset.required == [:password, :email]
    end

    test "allows fields to be set" do
      email = unique_<%= schema.singular %>_email()
      password = valid_<%= schema.singular %>_password()

      changeset =
        <%= inspect context.alias %>.change_<%= schema.singular %>_registration(
          %<%= inspect schema.alias %>{},
          valid_<%= schema.singular %>_attributes(email: email, password: password)
        )

      assert changeset.valid?
      assert get_change(changeset, :email) == email
      assert get_change(changeset, :password) == password
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "change_<%= schema.singular %>_email/2" do
    test "returns a <%= schema.singular %> changeset" do
      assert %Ecto.Changeset{} = changeset = <%= inspect context.alias %>.change_<%= schema.singular %>_email(%<%= inspect schema.alias %>{})
      assert changeset.required == [:email]
    end
  end

  describe "apply_<%= schema.singular %>_email/3" do
    setup do
      %{<%= schema.singular %>: <%= schema.singular %>_fixture()}
    end

    test "requires email to change", %{<%= schema.singular %>: <%= schema.singular %>} do
      {:error, changeset} = <%= inspect context.alias %>.apply_<%= schema.singular %>_email(<%= schema.singular %>, valid_<%= schema.singular %>_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{<%= schema.singular %>: <%= schema.singular %>} do
      {:error, changeset} =
        <%= inspect context.alias %>.apply_<%= schema.singular %>_email(<%= schema.singular %>, valid_<%= schema.singular %>_password(), %{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{<%= schema.singular %>: <%= schema.singular %>} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        <%= inspect context.alias %>.apply_<%= schema.singular %>_email(<%= schema.singular %>, valid_<%= schema.singular %>_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{<%= schema.singular %>: <%= schema.singular %>} do
      %{email: email} = <%= schema.singular %>_fixture()

      {:error, changeset} =
        <%= inspect context.alias %>.apply_<%= schema.singular %>_email(<%= schema.singular %>, valid_<%= schema.singular %>_password(), %{email: email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates current password", %{<%= schema.singular %>: <%= schema.singular %>} do
      {:error, changeset} =
        <%= inspect context.alias %>.apply_<%= schema.singular %>_email(<%= schema.singular %>, "invalid", %{email: unique_<%= schema.singular %>_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{<%= schema.singular %>: <%= schema.singular %>} do
      email = unique_<%= schema.singular %>_email()
      {:ok, <%= schema.singular %>} = <%= inspect context.alias %>.apply_<%= schema.singular %>_email(<%= schema.singular %>, valid_<%= schema.singular %>_password(), %{email: email})
      assert <%= schema.singular %>.email == email
      assert <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= schema.singular %>.id).email != email
    end
  end

  describe "deliver_update_email_instructions/3" do
    setup do
      %{<%= schema.singular %>: <%= schema.singular %>_fixture()}
    end

    test "sends token through notification", %{<%= schema.singular %>: <%= schema.singular %>} do
      token =
        extract_<%= schema.singular %>_token(fn url ->
          <%= inspect context.alias %>.deliver_update_email_instructions(<%= schema.singular %>, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert <%= schema.singular %>_token = Repo.get_by(<%= inspect schema.alias %>Token, token: :crypto.hash(:sha256, token))
      assert <%= schema.singular %>_token.<%= schema.singular %>_id == <%= schema.singular %>.id
      assert <%= schema.singular %>_token.sent_to == <%= schema.singular %>.email
      assert <%= schema.singular %>_token.context == "change:current@example.com"
    end
  end

  describe "update_<%= schema.singular %>_email/2" do
    setup do
      <%= schema.singular %> = <%= schema.singular %>_fixture()
      email = unique_<%= schema.singular %>_email()

      token =
        extract_<%= schema.singular %>_token(fn url ->
          <%= inspect context.alias %>.deliver_update_email_instructions(%{<%= schema.singular %> | email: email}, <%= schema.singular %>.email, url)
        end)

      %{<%= schema.singular %>: <%= schema.singular %>, token: token, email: email}
    end

    test "updates the email with a valid token", %{<%= schema.singular %>: <%= schema.singular %>, token: token, email: email} do
      assert <%= inspect context.alias %>.update_<%= schema.singular %>_email(<%= schema.singular %>, token) == :ok
      changed_<%= schema.singular %> = Repo.get!(<%= inspect schema.alias %>, <%= schema.singular %>.id)
      assert changed_<%= schema.singular %>.email != <%= schema.singular %>.email
      assert changed_<%= schema.singular %>.email == email
      assert changed_<%= schema.singular %>.confirmed_at
      assert changed_<%= schema.singular %>.confirmed_at != <%= schema.singular %>.confirmed_at
      refute Repo.get_by(<%= inspect schema.alias %>Token, <%= schema.singular %>_id: <%= schema.singular %>.id)
    end

    test "does not update email with invalid token", %{<%= schema.singular %>: <%= schema.singular %>} do
      assert <%= inspect context.alias %>.update_<%= schema.singular %>_email(<%= schema.singular %>, "oops") == :error
      assert Repo.get!(<%= inspect schema.alias %>, <%= schema.singular %>.id).email == <%= schema.singular %>.email
      assert Repo.get_by(<%= inspect schema.alias %>Token, <%= schema.singular %>_id: <%= schema.singular %>.id)
    end

    test "does not update email if <%= schema.singular %> email changed", %{<%= schema.singular %>: <%= schema.singular %>, token: token} do
      assert <%= inspect context.alias %>.update_<%= schema.singular %>_email(%{<%= schema.singular %> | email: "current@example.com"}, token) == :error
      assert Repo.get!(<%= inspect schema.alias %>, <%= schema.singular %>.id).email == <%= schema.singular %>.email
      assert Repo.get_by(<%= inspect schema.alias %>Token, <%= schema.singular %>_id: <%= schema.singular %>.id)
    end

    test "does not update email if token expired", %{<%= schema.singular %>: <%= schema.singular %>, token: token} do
      {1, nil} = Repo.update_all(<%= inspect schema.alias %>Token, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert <%= inspect context.alias %>.update_<%= schema.singular %>_email(<%= schema.singular %>, token) == :error
      assert Repo.get!(<%= inspect schema.alias %>, <%= schema.singular %>.id).email == <%= schema.singular %>.email
      assert Repo.get_by(<%= inspect schema.alias %>Token, <%= schema.singular %>_id: <%= schema.singular %>.id)
    end
  end

  describe "change_<%= schema.singular %>_password/2" do
    test "returns a <%= schema.singular %> changeset" do
      assert %Ecto.Changeset{} = changeset = <%= inspect context.alias %>.change_<%= schema.singular %>_password(%<%= inspect schema.alias %>{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        <%= inspect context.alias %>.change_<%= schema.singular %>_password(%<%= inspect schema.alias %>{}, %{
          "password" => "new valid password"
        })

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_<%= schema.singular %>_password/3" do
    setup do
      %{<%= schema.singular %>: <%= schema.singular %>_fixture()}
    end

    test "validates password", %{<%= schema.singular %>: <%= schema.singular %>} do
      {:error, changeset} =
        <%= inspect context.alias %>.update_<%= schema.singular %>_password(<%= schema.singular %>, valid_<%= schema.singular %>_password(), %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{<%= schema.singular %>: <%= schema.singular %>} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        <%= inspect context.alias %>.update_<%= schema.singular %>_password(<%= schema.singular %>, valid_<%= schema.singular %>_password(), %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{<%= schema.singular %>: <%= schema.singular %>} do
      {:error, changeset} =
        <%= inspect context.alias %>.update_<%= schema.singular %>_password(<%= schema.singular %>, "invalid", %{password: valid_<%= schema.singular %>_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{<%= schema.singular %>: <%= schema.singular %>} do
      {:ok, <%= schema.singular %>} =
        <%= inspect context.alias %>.update_<%= schema.singular %>_password(<%= schema.singular %>, valid_<%= schema.singular %>_password(), %{
          password: "new valid password"
        })

      assert is_nil(<%= schema.singular %>.password)
      assert <%= inspect context.alias %>.get_<%= schema.singular %>_by_email_and_password(<%= schema.singular %>.email, "new valid password")
    end

    test "deletes all tokens for the given <%= schema.singular %>", %{<%= schema.singular %>: <%= schema.singular %>} do
      _ = <%= inspect context.alias %>.generate_<%= schema.singular %>_session_token(<%= schema.singular %>)

      {:ok, _} =
        <%= inspect context.alias %>.update_<%= schema.singular %>_password(<%= schema.singular %>, valid_<%= schema.singular %>_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(<%= inspect schema.alias %>Token, <%= schema.singular %>_id: <%= schema.singular %>.id)
    end
  end

  describe "generate_<%= schema.singular %>_session_token/1" do
    setup do
      %{<%= schema.singular %>: <%= schema.singular %>_fixture()}
    end

    test "generates a token", %{<%= schema.singular %>: <%= schema.singular %>} do
      token = <%= inspect context.alias %>.generate_<%= schema.singular %>_session_token(<%= schema.singular %>)
      assert <%= schema.singular %>_token = Repo.get_by(<%= inspect schema.alias %>Token, token: token)
      assert <%= schema.singular %>_token.context == "session"

      # Creating the same token for another <%= schema.singular %> should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%<%= inspect schema.alias %>Token{
          token: <%= schema.singular %>_token.token,
          <%= schema.singular %>_id: <%= schema.singular %>_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_<%= schema.singular %>_by_session_token/1" do
    setup do
      <%= schema.singular %> = <%= schema.singular %>_fixture()
      token = <%= inspect context.alias %>.generate_<%= schema.singular %>_session_token(<%= schema.singular %>)
      %{<%= schema.singular %>: <%= schema.singular %>, token: token}
    end

    test "returns <%= schema.singular %> by token", %{<%= schema.singular %>: <%= schema.singular %>, token: token} do
      assert session_<%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>_by_session_token(token)
      assert session_<%= schema.singular %>.id == <%= schema.singular %>.id
    end

    test "does not return <%= schema.singular %> for invalid token" do
      refute <%= inspect context.alias %>.get_<%= schema.singular %>_by_session_token("oops")
    end

    test "does not return <%= schema.singular %> for expired token", %{token: token} do
      {1, nil} = Repo.update_all(<%= inspect schema.alias %>Token, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute <%= inspect context.alias %>.get_<%= schema.singular %>_by_session_token(token)
    end
  end

  describe "delete_session_token/1" do
    test "deletes the token" do
      <%= schema.singular %> = <%= schema.singular %>_fixture()
      token = <%= inspect context.alias %>.generate_<%= schema.singular %>_session_token(<%= schema.singular %>)
      assert <%= inspect context.alias %>.delete_session_token(token) == :ok
      refute <%= inspect context.alias %>.get_<%= schema.singular %>_by_session_token(token)
    end
  end

  describe "deliver_<%= schema.singular %>_confirmation_instructions/2" do
    setup do
      %{<%= schema.singular %>: <%= schema.singular %>_fixture()}
    end

    test "sends token through notification", %{<%= schema.singular %>: <%= schema.singular %>} do
      token =
        extract_<%= schema.singular %>_token(fn url ->
          <%= inspect context.alias %>.deliver_<%= schema.singular %>_confirmation_instructions(<%= schema.singular %>, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert <%= schema.singular %>_token = Repo.get_by(<%= inspect schema.alias %>Token, token: :crypto.hash(:sha256, token))
      assert <%= schema.singular %>_token.<%= schema.singular %>_id == <%= schema.singular %>.id
      assert <%= schema.singular %>_token.sent_to == <%= schema.singular %>.email
      assert <%= schema.singular %>_token.context == "confirm"
    end
  end

  describe "confirm_<%= schema.singular %>/1" do
    setup do
      <%= schema.singular %> = <%= schema.singular %>_fixture()

      token =
        extract_<%= schema.singular %>_token(fn url ->
          <%= inspect context.alias %>.deliver_<%= schema.singular %>_confirmation_instructions(<%= schema.singular %>, url)
        end)

      %{<%= schema.singular %>: <%= schema.singular %>, token: token}
    end

    test "confirms the email with a valid token", %{<%= schema.singular %>: <%= schema.singular %>, token: token} do
      assert {:ok, confirmed_<%= schema.singular %>} = <%= inspect context.alias %>.confirm_<%= schema.singular %>(token)
      assert confirmed_<%= schema.singular %>.confirmed_at
      assert confirmed_<%= schema.singular %>.confirmed_at != <%= schema.singular %>.confirmed_at
      assert Repo.get!(<%= inspect schema.alias %>, <%= schema.singular %>.id).confirmed_at
      refute Repo.get_by(<%= inspect schema.alias %>Token, <%= schema.singular %>_id: <%= schema.singular %>.id)
    end

    test "does not confirm with invalid token", %{<%= schema.singular %>: <%= schema.singular %>} do
      assert <%= inspect context.alias %>.confirm_<%= schema.singular %>("oops") == :error
      refute Repo.get!(<%= inspect schema.alias %>, <%= schema.singular %>.id).confirmed_at
      assert Repo.get_by(<%= inspect schema.alias %>Token, <%= schema.singular %>_id: <%= schema.singular %>.id)
    end

    test "does not confirm email if token expired", %{<%= schema.singular %>: <%= schema.singular %>, token: token} do
      {1, nil} = Repo.update_all(<%= inspect schema.alias %>Token, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert <%= inspect context.alias %>.confirm_<%= schema.singular %>(token) == :error
      refute Repo.get!(<%= inspect schema.alias %>, <%= schema.singular %>.id).confirmed_at
      assert Repo.get_by(<%= inspect schema.alias %>Token, <%= schema.singular %>_id: <%= schema.singular %>.id)
    end
  end

  describe "deliver_<%= schema.singular %>_reset_password_instructions/2" do
    setup do
      %{<%= schema.singular %>: <%= schema.singular %>_fixture()}
    end

    test "sends token through notification", %{<%= schema.singular %>: <%= schema.singular %>} do
      token =
        extract_<%= schema.singular %>_token(fn url ->
          <%= inspect context.alias %>.deliver_<%= schema.singular %>_reset_password_instructions(<%= schema.singular %>, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert <%= schema.singular %>_token = Repo.get_by(<%= inspect schema.alias %>Token, token: :crypto.hash(:sha256, token))
      assert <%= schema.singular %>_token.<%= schema.singular %>_id == <%= schema.singular %>.id
      assert <%= schema.singular %>_token.sent_to == <%= schema.singular %>.email
      assert <%= schema.singular %>_token.context == "reset_password"
    end
  end

  describe "get_<%= schema.singular %>_by_reset_password_token/1" do
    setup do
      <%= schema.singular %> = <%= schema.singular %>_fixture()

      token =
        extract_<%= schema.singular %>_token(fn url ->
          <%= inspect context.alias %>.deliver_<%= schema.singular %>_reset_password_instructions(<%= schema.singular %>, url)
        end)

      %{<%= schema.singular %>: <%= schema.singular %>, token: token}
    end

    test "returns the <%= schema.singular %> with valid token", %{<%= schema.singular %>: %{id: id}, token: token} do
      assert %<%= inspect schema.alias %>{id: ^id} = <%= inspect context.alias %>.get_<%= schema.singular %>_by_reset_password_token(token)
      assert Repo.get_by(<%= inspect schema.alias %>Token, <%= schema.singular %>_id: id)
    end

    test "does not return the <%= schema.singular %> with invalid token", %{<%= schema.singular %>: <%= schema.singular %>} do
      refute <%= inspect context.alias %>.get_<%= schema.singular %>_by_reset_password_token("oops")
      assert Repo.get_by(<%= inspect schema.alias %>Token, <%= schema.singular %>_id: <%= schema.singular %>.id)
    end

    test "does not return the <%= schema.singular %> if token expired", %{<%= schema.singular %>: <%= schema.singular %>, token: token} do
      {1, nil} = Repo.update_all(<%= inspect schema.alias %>Token, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute <%= inspect context.alias %>.get_<%= schema.singular %>_by_reset_password_token(token)
      assert Repo.get_by(<%= inspect schema.alias %>Token, <%= schema.singular %>_id: <%= schema.singular %>.id)
    end
  end

  describe "reset_<%= schema.singular %>_password/2" do
    setup do
      %{<%= schema.singular %>: <%= schema.singular %>_fixture()}
    end

    test "validates password", %{<%= schema.singular %>: <%= schema.singular %>} do
      {:error, changeset} =
        <%= inspect context.alias %>.reset_<%= schema.singular %>_password(<%= schema.singular %>, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{<%= schema.singular %>: <%= schema.singular %>} do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = <%= inspect context.alias %>.reset_<%= schema.singular %>_password(<%= schema.singular %>, %{password: too_long})
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{<%= schema.singular %>: <%= schema.singular %>} do
      {:ok, updated_<%= schema.singular %>} = <%= inspect context.alias %>.reset_<%= schema.singular %>_password(<%= schema.singular %>, %{password: "new valid password"})
      assert is_nil(updated_<%= schema.singular %>.password)
      assert <%= inspect context.alias %>.get_<%= schema.singular %>_by_email_and_password(<%= schema.singular %>.email, "new valid password")
    end

    test "deletes all tokens for the given <%= schema.singular %>", %{<%= schema.singular %>: <%= schema.singular %>} do
      _ = <%= inspect context.alias %>.generate_<%= schema.singular %>_session_token(<%= schema.singular %>)
      {:ok, _} = <%= inspect context.alias %>.reset_<%= schema.singular %>_password(<%= schema.singular %>, %{password: "new valid password"})
      refute Repo.get_by(<%= inspect schema.alias %>Token, <%= schema.singular %>_id: <%= schema.singular %>.id)
    end
  end

  describe "inspect/2" do
    test "does not include password" do
      refute inspect(%<%= inspect schema.alias %>{password: "123456"}) =~ "password: \"123456\""
    end
  end

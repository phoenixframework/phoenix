defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>SessionHTML do
  use <%= inspect context.web_module %>, :html

  embed_templates "<%= schema.singular %>_session_html/*"

  defp local_mail_adapter? do
    Application.get_env(:<%= Mix.Phoenix.otp_app() %>, <%= inspect context.base_module %>.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end

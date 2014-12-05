defmodule <%= application_module %>.I18n do
  use Linguist.Vocabulary

  locale "en", Path.join([__DIR__, "../config/locales/en.exs"])

  # locale "fr", Path.join([__DIR__, "../config/locales/fr.exs"])
end

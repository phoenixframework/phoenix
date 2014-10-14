defmodule <%= application_module %>.View do
  use Phoenix.View, root: "web/templates"

  # Everything in this block is available runs in this
  # module and in other views that use MyApp.View
  using do
    # Import common functionality
    import <%= application_module %>.I18n
    import <%= application_module %>.Router.Helpers

    # Use Phoenix.HTML to import all HTML functions (forms, tags, etc)
    use Phoenix.HTML

    # Common aliases
    alias Phoenix.Controller.Flash
  end

  # Functions defined here are available to all other views/templates
end

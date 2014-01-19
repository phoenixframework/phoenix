defmodule Phoenix.Naming do

  def snake_to_camel_case(name) do
    Regex.split(%r/(?:^|[-_])(\w)/, to_string(name)) |> Enum.map_join(fn
      char when byte_size(char) == 1 -> String.upcase(char)
      part -> part
    end)
  end
end

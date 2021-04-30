defmodule Phoenix.Digester.GzipTest do
  use ExUnit.Case, async: true
  alias Phoenix.Digester.Gzip

  test "compress_file/2 compresses file" do
    file_path = "test/fixtures/digest/priv/static/css/app.css"
    content = File.read!(file_path)

    {:ok, compressed} = Gzip.compress_file(file_path, content)

    assert is_binary(compressed)
  end
end

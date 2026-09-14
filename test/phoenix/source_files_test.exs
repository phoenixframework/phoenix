defmodule Phoenix.SourceFilesTest do
  use ExUnit.Case, async: true

  @repo_root Path.expand("../..", __DIR__)
  @git_repo? File.dir?(Path.join(@repo_root, ".git")) and System.find_executable("git") != nil
  @excluded_exts ~w(.br .foo .gz .ico .lock .map .pem .png)
  @excluded_files ~w(test/fixtures/hello.txt)

  @tag skip: if(not @git_repo?, do: "git or .git repository not available")
  test "all tracked text files in the repository end with a single newline" do
    {output, 0} = System.cmd("git", ["ls-files", "-z"], cd: @repo_root)

    target_files =
      output
      |> String.split("\0", trim: true)
      |> Enum.reject(fn file ->
        file in @excluded_files or Enum.any?(@excluded_exts, &String.ends_with?(file, &1))
      end)
      |> Enum.map(&Path.expand(&1, @repo_root))
      |> Enum.filter(&File.regular?/1)

    assert target_files != [], "No tracked files found in the repository"

    offending =
      target_files
      |> Enum.reject(fn file ->
        content = File.read!(file)
        content == "" or content =~ ~r/\S\n\z/
      end)
      |> Enum.map(&Path.relative_to(&1, @repo_root))

    assert offending == [],
           "Expected the following files to end with a single trailing newline:\n\n" <>
             Enum.map_join(offending, "\n", &"  - #{&1}")
  end
end

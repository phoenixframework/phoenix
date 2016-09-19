defmodule Phoenix.DigestCleaner do
  @digested_file_regex ~r/(-[a-fA-F\d]{32})/

  @moduledoc """
  Cleans old versions of compiled assets.
  """

  @doc """
  Digests and compresses the static files and saves them in the given output path.

    * `output_path` - The path where the compiled/compressed files will be saved
    * `age` - The max age of assets to keep
    * `keep` - The number of old versions to keep
  """
  @spec clean(String.t, integer, integer, integer) :: :ok | {:error, :invalid_path}
  def clean(output_path, age, keep, now \\ :calendar.datetime_to_gregorian_seconds(:calendar.universal_time)) do
    if File.exists?(output_path) do
      digests = load_digests(output_path) || %{}
      clean_files(output_path, digests, now - age, keep)
      :ok
    else
      {:error, :invalid_path}
    end
  end

  defp load_digests(path) do
    manifest_path = Path.join(path, "manifest.json")
    if File.exists?(manifest_path) do
      manifest_path
      |> File.read!
      |> Poison.decode!
      |> Access.get("digests")
    end
  end

  defp clean_files(output_path, digests, max_age, keep) do
    for {_, versions} <- group_by_logical_path(digests) do
      versions
      |> Enum.map(fn {path, attrs} -> Map.put(attrs, "path", path) end)
      |> Enum.sort(&(&1["mtime"] > &2["mtime"]))
      |> Stream.with_index
      |> Enum.filter(fn {version, index} ->
        max_age > version["mtime"] || index > keep
      end)
      |> remove_versions(output_path)
    end
  end

  defp group_by_logical_path(digests) do
    digests
    |> Enum.group_by(fn {_, attrs} -> attrs["logical_path"] end)
  end

  defp remove_versions(versions, output_path) do
    for {version, _index} <- versions do
      output_path
      |> Path.join(version["path"])
      |> File.rm

      output_path
      |> Path.join("#{version["path"]}.gz")
      |> File.rm
    end
  end
end

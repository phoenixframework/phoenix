defmodule Phoenix.Integration.MixTaskRunner do
  @moduledoc """
  This runs mix tasks via the command-line.

  This is useful for running tasks in projects outside of the
  current BEAM instance.
  """

  @type opt ::
          {:cd, String.t()}
          | {:env, [{String.t(), String.t()}]}

  @type args :: [String.t()]

  @spec run(args, [opt]) :: {String.t(), exit_status :: non_neg_integer()}
  def run(args, opts \\ []) when is_list(args) and is_list(opts) do
    System.cmd("mix", args, [stderr_to_stdout: true] ++ opts)
  end

  def run!(args, opts) when is_list(args) and is_list(opts) do
    case run(args, opts) do
      {output, 0} ->
        output

      {output, exit_code} ->
        raise """
        mix command failed with exit code: #{inspect(exit_code)}

        mix #{Enum.join(args, " ")}

        #{output}

        Options
          cd: #{get_cd(opts)}
          env: #{inspect(get_env(opts))}
        """
    end
  end

  defp get_cd(opts), do: opts |> Keyword.get_lazy(:cd, &File.cwd!/0) |> Path.expand()

  defp get_env(opts) do
    Keyword.get(opts, :env, [])
  end
end

defmodule Phoenix.Integration.MixTaskRunner do
  @moduledoc """
  This runs mix tasks via the command-line.
  This is useful for running tasks in projects outside of the
  current BEAM instance.
  """

  use GenServer

  @type prompt_response :: :no_to_all | :yes_to_all | String.t() | [String.t()]
  @type opt ::
          {:prompt_responses, [prompt_response]}
          | {:cd, String.t()}
          | {:env, [{String.t(), String.t()}]}

  @type args :: [String.t()]

  @spec start_link(args, [opt]) :: GenServer.on_start()
  def start_link(args, opts) when is_list(args) and is_list(opts) do
    parent_pid = self()
    GenServer.start_link(__MODULE__, {parent_pid, args, opts})
  end

  @spec run(args, [opt]) :: {String.t(), exit_status :: non_neg_integer()}
  def run(args, opts \\ []) when is_list(args) and is_list(opts) do
    {:ok, pid} = start_link(args, opts)

    receive do
      {:unexpected_prompt, ^pid, {prompt, all_output}} ->
        raise """
        unexpected prompt

          #{prompt}

        All output:

        #{all_output}
        """

      {:command_exited, ^pid, {output, exit_code}} ->
        {output, exit_code}
    end
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

  @impl true
  def init({parent_pid, args, opts}) do
    mix_path = System.find_executable("mix")
    port_options = extract_port_options(opts)

    prompt_responses =
      opts
      |> Keyword.get(:prompt_responses, [])
      |> List.wrap()

    port =
      Port.open(
        {:spawn_executable, mix_path},
        [:exit_status, :stderr_to_stdout, args: args, env: get_env(opts)] ++ port_options
      )

    state = %{
      port: port,
      parent_pid: parent_pid,
      output_iodata: [],
      prompt_responses: prompt_responses
    }

    {:ok, state}
  end

  defp extract_port_options([{:cd, dir} | rest]) do
    [{:cd, to_charlist(dir)} | extract_port_options(rest)]
  end

  defp extract_port_options([_ | rest]) do
    extract_port_options(rest)
  end

  defp extract_port_options([]), do: []

  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    data = List.to_string(data)
    state = %{state | output_iodata: [state.output_iodata | data]}

    case process_output(data, state) do
      {:ok, state} ->
        {:noreply, state}

      {:error, :unexpected_prompt, prompt} ->
        send(state.parent_pid, {:unexpected_prompt, self(), {prompt, get_output(state)}})
        {:stop, :normal, state}
    end
  end

  def handle_info({port, {:exit_status, exit_status}}, %{port: port} = state) do
    send(state.parent_pid, {:command_exited, self(), {get_output(state), exit_status}})
    {:stop, :normal, state}
  end

  defp process_output(data, state) do
    case analyze_output(data) do
      {:prompt, prompt} ->
        handle_prompt(prompt, state)

      {:output, _} ->
        {:ok, state}
    end
  end

  defp analyze_output(output) do
    if Regex.match?(~r/\? \[yn\]/i, output) do
      {:prompt, output}
    else
      {:output, output}
    end
  end

  defp handle_prompt(_prompt, %{prompt_responses: [response | rest], port: port} = state)
       when is_binary(response) do
    Port.command(port, response <> "\n")
    {:ok, %{state | prompt_responses: [rest]}}
  end

  defp handle_prompt(_prompt, %{prompt_responses: [:yes_to_all | _], port: port} = state) do
    Port.command(port, "y\n")
    {:ok, state}
  end

  defp handle_prompt(_prompt, %{prompt_responses: [:no_to_all | _], port: port} = state) do
    Port.command(port, "n\n")
    {:ok, state}
  end

  defp handle_prompt(prompt, %{prompt_responses: []}) do
    {:error, :unexpected_prompt, prompt}
  end

  defp get_output(%{output_iodata: output_iodata}) do
    IO.iodata_to_binary(output_iodata)
  end

  defp get_cd(opts), do: opts |> Keyword.get_lazy(:cd, &File.cwd!/0) |> Path.expand()

  defp get_env(opts) do
    opts
    |> Keyword.get(:env, [])
    |> Enum.map(fn {key, val} -> {to_charlist(key), to_charlist(val)} end)
  end
end

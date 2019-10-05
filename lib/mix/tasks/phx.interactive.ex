defmodule Mix.Tasks.Phx.Interactive do
    use Mix.Task
   
    @shortdoc "Phoenix Interactive Installer Prompt"
  
    @moduledoc """
    Runs the phx interactive installer.
    """
    def installer(project) do
        app_name = Mix.Shell.IO.prompt("Enter the name of the OTP application") 
        app_module = Mix.Shell.IO.prompt("Enter the name of the base module in the generated skeleton")
        is_umbrella? = Mix.Shell.IO.yes?("Is this an umbrella application?")
       
        project = %{ project | "app" => app_name }
        project = %{ project | "app_mod" => app_module }

        project = case is_umbrella? do
            true -> %{ project | "in_umbrella?" => true }
            false -> project
        end
        
        project
    end

    def run([]) do
        Mix.Tasks.Help.run(["phx.new"])
      end

    def run(args) do
        Mix.Tasks.Phx.New.run(args ++ ["--interactive"])
      end
    end
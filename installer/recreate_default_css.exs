File.rm_rf!("installer/dayzee")

shell! = fn command, opts ->
  {_, 0} =
    System.shell(
      command,
      Keyword.merge(
        [
          into: IO.binstream(:stdio, :line),
          stderr_to_stdout: true
        ],
        opts
      )
    )
end

shell_in_daisy! = fn command -> shell!.(command, cd: Path.expand("dayzee")) end

File.cd!("installer", fn ->
  shell!.("mix phx.new dayzee --dev --database sqlite3 --install", [])

  shell_in_daisy!.("mix phx.gen.auth Accounts User users --live")
  shell_in_daisy!.("mix deps.get")
  shell_in_daisy!.("mix phx.gen.live Blog Post posts title:string body:text")
  shell_in_daisy!.("mix tailwind dayzee")

  content = File.read!("dayzee/priv/static/assets/css/app.css")

  File.write!("templates/phx_static/default.css", """
  /* These are daisyUI styles for styling the default CoreComponents and generator files
   * included to prevent shipping a completely unstyled page, even as you selected --no-tailwind.
   * You can safely remove the whole file and all references to "default.css".
   */
  #{content}
  """)
end)

File.rm_rf!("installer/dayzee")

## mix phx.new

Provides `phx.new` installer as an archive. To build and install it locally
ensure any previous archive versions are removed:

    $ mix archive.uninstall phx_new

Then run:

    $ cd installer
    $ MIX_ENV=prod mix do archive.build, archive.install

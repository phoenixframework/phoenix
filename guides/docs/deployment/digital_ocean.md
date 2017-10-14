# Deploying Phoenix to DigitalOcean

- [Part 1](https://medium.com/@zek/deploy-early-and-often-deploying-phoenix-with-edeliver-and-distillery-part-one-5e91cac8d4bd)
- [Part 2](https://medium.com/@zek/deploy-early-and-often-deploying-phoenix-with-edeliver-and-distillery-part-two-f361ef36aa10)

# Gotchas for Phoenix v1.3

_Credits to [this comment](https://medium.com/@ian_32298/thanks-for-the-blog-post-i-had-to-change-the-following-to-get-it-to-work-with-phoenix-v1-3-64ef20c6d6eb)_

#### Don't add the `http: [port: 8888]` config in `config/prod.exs`

Instead, you'll need to add `export PORT=8888` to `~/.profile` on your DigitalOcean droplet.

#### Read this when you get to the step for creating a `.deliver/config` file.

Replace the function below in `.deliver/config`

```
pre_erlang_clean_compile() {
  status "Running phx.digest" # log output prepended with "----->"
  __sync_remote " # runs the commands on the build host
    # [ -f ~/.profile ] && source ~/.profile # load profile (optional)
    source ~/.profile

    # echo \$PATH # check if rbenv is in the path
    set -e # fail if any command fails (recommended)
    cd '$BUILD_AT' # enter the build directory on the build host (required)

    # prepare something
    mkdir -p priv/static # required by the phoenix.digest task
    ( cd assets && npm install && ./node_modules/brunch/bin/brunch build --production )

    # run your custom task
    APP='$APP' MIX_ENV='$TARGET_MIX_ENV' $MIX_CMD phx.digest $SILENCE
  "
}
```

#### `mix edeliver start production`

The `response` for this command should be `response: ok`.

# Other useful resources

- [Securing your app with SSL](https://medium.com/@zek/secure-your-phoenix-app-with-free-ssl-48ac749c17d7)

- [Automated Backups with the Ruby Backup Gem and Amazon S3](https://medium.com/@zek/automated-backups-with-the-ruby-backup-gem-and-amazon-s3-f0f2f986876e)

# <%= application_module %>

To start your new Phoenix application:

1. Install dependencies with `mix deps.get`
2. Start Phoenix endpoint with `mix phoenix.server`

Now you can visit `localhost:4000` from your browser.

# Deploying your App to Heroku

[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy)

The deploy button above allows you to instantly deploy your applications to Heroku from your Github
repo. If deploying from a public Github repo, this will work as soon as you commit `prod.secret.exs` into version control. You can do this by commenting it out in your `.gitignore`. Keep in mind to remove all hardcoded secrets before committing `prod.secret.exs`!

If deploying from a private repo, you will also need to provide an explicit `template` parameter to the button's `href`. Your deploy button will look like `[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy?template=https://github.com/username/appname)`.

Phoenix generates an `app.json` file. This JSON schema is used by Heroku to customize your deploy. It includes a lot of useful configuration. From here you can set deploy hooks, the buildpacks used, and ENV variables for your app, among other options. To learn more about it, refer to [app.json schema docs](https://devcenter.heroku.com/articles/app-json-schema) in Heroku.

If you want to learn more on customizing or debugging the Heroku button, Heroku provides a [great resource](https://devcenter.heroku.com/articles/heroku-button) on the topic.

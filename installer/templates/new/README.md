# <%= application_module %>

To start your new Phoenix application:

1. Install dependencies with `mix deps.get`
2. Start Phoenix endpoint with `mix phoenix.server`

Now you can visit `localhost:4000` from your browser.

# Deploying your App to Heroku

[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy)

The deploy button above allows you to instantly deploy your applications to Heroku from your Github
repo. This will work out-of-the-box when deploying from a public Github repo. If deploying from a
private repo, you will need to provide an explicit `template` parameter to the button's `href`. Your
deploy button will look like `[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy?template=https://github.com/username/appname)`.

There are a few files generated for your Phoenix app so the Heroku deploy button would work. These are:

- app.json - this JSON schema is used by Heroku to customize your deploy. It includes a lot of useful
  configuration. From here you can set deploy hooks, the buildpack URL and ENV variables for your app,
  among other options. To learn more about it, refer to [app.json schema docs](https://devcenter.heroku.com/articles/app-json-schema) in Heroku.
- .buildpacks - we rely on [heroku-buildpack-multi](https://github.com/ddollar/heroku-buildpack-multi)which requires this file so it knows which buildpacks to use. You may customize buildpacks from here.

If you want to learn more on customize or debugging the Heroku button, Heroku provides a [great resource](https://devcenter.heroku.com/articles/heroku-button)
on the topic.

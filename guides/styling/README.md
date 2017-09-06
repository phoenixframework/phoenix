Most of this is stock HTML and CSS from the Readme.io website.

For the most part, the only changes you will need to make are in Phoenix_files/custom.scss.

Make sure to install Sass and then run

    sass --watch ./Phoenix_files/custom.scss

That will make sure to update the css as you are working on it.

## Moving to Readme.io

Before copying custom.css to Readme.io, remember to remove the selector for
`.header h1.navbar-brand a`. That is only used in development so the logo shows up.

exports.config = {
  // See http://brunch.io/#documentation for docs.
  files: {
    javascripts: {
      joinTo: 'js/app.js'
      // To change the order of concatenation of files, explictly mention here
      // https://github.com/brunch/brunch/tree/stable/docs#concatenation
      // order: {
      //   before: [
      //     'web/static/vendor/js/jquery-2.1.1.js',
      //     'web/static/vendor/js/bootstrap.min.js'
      //   ]
      // }
    },
    stylesheets: {
      joinTo: 'css/app.css'
    },
    templates: {
      joinTo: 'js/app.js'
    }
  },

  // Phoenix paths configuration
  paths: {
    // Which directories to watch
    watched: ["web/static", "test/static"],

    // Where to compile files to
    public: "priv/static"
  },

  // Configure your plugins
  plugins: {
    ES6to5: {
      // Do not use ES6 compiler in vendor code
      ignore: [/^(web\/static\/vendor)/]
    }
  }
};

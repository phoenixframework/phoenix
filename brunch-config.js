exports.config = {
  // See http://brunch.io/#documentation for docs.
  sourceMaps: false,
  production: true,
  modules: {
    // use common js wrapper, but expose global `Phoenix` object for browser
    // truncate module path simple to "phoenix"
    wrapper: function(path, data){
      return(
        "require.define({'phoenix': function(exports, require, module){ " + data + " }});\n" +
        "if(typeof(window) === 'object' && !window.Phoenix){ window.Phoenix = require('phoenix') };"
      )
    }
  },
  files: {
    javascripts: {
      joinTo: 'phoenix.js'
    },
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
    babel: {
      // Do not use ES6 compiler in vendor code
      ignore: [/^(web\/static\/vendor)/],
      loose: "all"
    }
  }
};

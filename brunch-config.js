exports.config = {
  sourceMaps: false,
  production: true,

  modules: {
    definition: false,
    // The wrapper for browsers in a way that:
    //
    // 1. Phoenix.Socket, Phoenix.Channel and so on are available
    // 2. the exports variable does not leak
    // 3. the Socket, Channel variables and so on do not leak
    wrapper: function(path, code){
      return "(function(exports){\n" + code + "\n})(typeof(exports) === \"undefined\" ? window.Phoenix = window.Phoenix || {} : exports);\n";
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
      ignore: [/^(web\/static\/vendor)/]
    }
  }
};

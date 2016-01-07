exports.config = {
  sourceMaps: false,
  production: true,

  modules: {
    wrapper: false,
    definition: false
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

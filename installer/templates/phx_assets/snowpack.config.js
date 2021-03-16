// Snowpack Configuration File
// See all supported options: https://www.snowpack.dev/reference/configuration

/** @type {import("snowpack").SnowpackUserConfig } */
module.exports = {
  mount: {
    "static/images": {url: "/images", static: true, resolve: false},
    "js": {url: "/js"},
    "css": {url: "/css"}
  },
  plugins: [
    "@snowpack/plugin-sass",
  ],
  packageOptions: {
    /* ... */
  },
  devOptions: {
    /* ... */
  },
  buildOptions: {
      out: "../priv/static",
      watch: true
  },
};


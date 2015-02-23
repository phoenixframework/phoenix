module.exports = {
  entry: "./phoenix.js",
  output: {
    path: "../../priv/static/js",
    library: "Phoenix",
    filename: "phoenix.js",
    libraryTarget: 'umd'
  },
  module: {
    loaders: [
      { test: /\.js?$/, exclude: /node_modules/, loader: "babel-loader"}
    ]
  }
}

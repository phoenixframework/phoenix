const path = require('path')

module.exports = {
  entry: './assets/js/phoenix.js',
  output: {
    filename: 'phoenix.js',
    path: path.resolve(__dirname, './priv/static')
  },
  module: {
    rules: [
      {
        test: /\.js$/,
        exclude: /node_modules/,
        use: {
          loader: 'babel-loader'
        }
      },
      {
        test: path.resolve(__dirname, './assets/js/phoenix.js'),
        use: [{
          loader: 'expose-loader',
          options: 'Phoenix'
        }]
      }
    ]
  },
  plugins: []
}

const path = require('path')

module.exports = {
  entry: './js/phoenix.js',
  output: {
    filename: 'phoenix.js',
    path: path.resolve(__dirname, '../priv/static'),
    library: 'Phoenix',
    libraryTarget: 'umd'
  },
  module: {
    rules: [
      {
        test: path.resolve(__dirname, './js/phoenix.js'),
        use: [{
          loader: 'expose-loader',
          options: 'Phoenix'
        }]
      },
      {
        test: /\.js$/,
        exclude: /node_modules/,
        use: {
          loader: 'babel-loader'
        }
      }
    ]
  },
  plugins: []
}

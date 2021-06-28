const path = require('path')

module.exports = (env, options) => {
  return {
    entry: './js/phoenix/index.js',
    output: {
      filename: 'phoenix.js',
      path: path.resolve(__dirname, '../priv/static'),
      library: {
        name: 'phoenix',
        type: 'umd'
      },
      globalObject: 'this'
    },
    devtool: 'source-map',
    module: {
      rules: [
        {
          test: require.resolve('phoenix'),
          loader: 'expose-loader',
          options: {
            exposes: ['Phoenix']
          }
        }
      ]
    },
    plugins: []
  }
}

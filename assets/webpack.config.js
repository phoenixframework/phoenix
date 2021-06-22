const path = require('path')

module.exports = (env, options) => {
  const devMode = options.mode !== 'production';

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
    devtool: devMode ? 'source-map' : undefined,
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

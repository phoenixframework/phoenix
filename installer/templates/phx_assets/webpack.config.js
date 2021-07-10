const path = require('path');
const CssMinimizerPlugin = require('css-minimizer-webpack-plugin');
const CopyPlugin = require('copy-webpack-plugin');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');

module.exports = (env, options) => {
  const devMode = options.mode !== 'production';

  return {
    entry: {
      'app': './js/app.js'
    },
    output: {
      filename: '[name].js',
      path: path.resolve(__dirname, '../priv/static/js'),
      publicPath: '/js/'
    },
    module: {
      rules: [
        {
          test: /\.css$/,
          use: [
            MiniCssExtractPlugin.loader,
            'css-loader'
          ],
        }
      ]
    },
    plugins: [
      new MiniCssExtractPlugin({ filename: '../css/[name].css' }),
      new CopyPlugin({
        patterns: [
          { from: 'static/', to: '../' }
        ]
      })
    ],
    optimization: {
      minimizer: [
        '...',
        new CssMinimizerPlugin()
      ]
    },
    devtool: devMode ? 'source-map' : undefined
  }
};

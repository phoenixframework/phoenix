const webpack = require("webpack");
const path = require('path');
const assetsRoot = __dirname;
const nodeModulesPath = path.join(assetsRoot, 'node_modules');
const privStaticPath = path.resolve(assetsRoot, '..', 'priv', 'static');
const buildPath = path.join(privStaticPath, 'bundles');
const jsPath = path.join(assetsRoot, 'js');
const stylesPath = path.join(assetsRoot, 'css');
const mainEntryFile = path.join(jsPath, 'app.js');

module.exports = {
    entry: {
        app: mainEntryFile
    },
    output: {
        path: buildPath,
        publicPath: '/js/',
        filename: '[name].js'
    },
    devtool: 'source-map',
    module: {
        rules: [
            { test: /.(png|woff(2)?|eot|ttf|svg|csv|jpe?g|csv)(\?[a-z0-9=\.]+)?$/, loader: 'url-loader?limit=10000' },
            { test: /\.css$/,  loaders: ['style-loader', 'resolve-url-loader'] },
            { test: /\.js$/,   loader: 'babel-loader', include: jsPath, exclude: /node_modules/ },
            { test: /\.html$/, loader: 'raw-loader' }
        ]
    },
    resolve: {
        extensions: ['.js', '.css'],
        alias: {
            'src': jsPath,
            'assets': assetsRoot,
            'styles': stylesPath,
            'node_modules': nodeModulesPath
        }
    },

    plugins: [
    ]
};

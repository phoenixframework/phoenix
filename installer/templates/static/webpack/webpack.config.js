const webpack = require("webpack");
const cpx = require("cpx");
const path = require("path");
const assetsRoot = __dirname;
const staticAssetsPath = path.join(assetsRoot, "static");
const nodeModulesPath = path.join(assetsRoot, "node_modules");
const privStaticPath = path.resolve(assetsRoot, "..", "priv", "static");
const buildPath = path.join(privStaticPath, "js");
const jsPath = path.join(assetsRoot, "js");
const stylesPath = path.join(assetsRoot, "css");
const mainEntryFile = path.join(jsPath, "app.js");


function cpxPlugin() {
}

cpxPlugin.prototype.apply = function(compiler) {
    var instance;
    if(compiler.options.watch) {
        instance = cpx.watch(staticAssetsPath + "/**/*", privStaticPath);
    } else {
        instance = cpx.copy(staticAssetsPath + "/**/*", privStaticPath);
    }

    instance.on("copy", function(e) { console.info("Copied: " + e.srcPath); });
};

module.exports = {
    entry: {
        app: mainEntryFile
    },
    output: {
        path: buildPath,
        publicPath: "/js/",
        filename: "[name].js"
    },
    devtool: "source-map",
    module: {
        rules: [
            { test: /.(png|woff(2)?|eot|ttf|svg|jpe?g)(\?[a-z0-9=\.]+)?$/, loader: "url-loader?limit=10000" },
            { test: /\.css$/,  loaders: ["style-loader", "css-loader"] },
            { test: /\.js$/,   loader: "babel-loader", include: jsPath, exclude: /node_modules/ }
        ]
    },
    resolve: {
        extensions: [".js", ".css"],
        alias: {
            "src": jsPath,
            "assets": assetsRoot,
            "styles": stylesPath,
            "node_modules": nodeModulesPath
        }
    },

    plugins: [
        new cpxPlugin()
    ]
};

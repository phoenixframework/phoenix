module.exports = {
    "env": {
        "browser": true,
        "es2021": true,
        "jest/globals": true
    },
    "extends": "eslint:recommended",
    "globals": {
        "global": "writable"
    },
    "parserOptions": {
        "ecmaVersion": 12,
        "sourceType": "module"
    },
    "plugins": [
        "jest"
    ],
    "rules": {
        "indent": [
            "error",
            2,
            {"SwitchCase": 1}
        ],
        "linebreak-style": [
            "error",
            "unix"
        ],
        "quotes": [
            "error",
            "double"
        ],
        "semi": [
            "error",
            "never"
        ],
        "object-curly-spacing": [
            "error",
            "never",
            {"objectsInObjects": false, "arraysInObjects": false}
        ],
        "array-bracket-spacing": [
            "error",
            "never"
        ],
        "comma-spacing": [
            "error",
            {"before": false, "after": true}
        ],
        "computed-property-spacing": [
            "error",
            "never"
        ],
        "space-before-blocks": [
            "error",
            {"functions": "never", "keywords": "never", "classes": "always"}
        ],
        "keyword-spacing": [
            "error",
            {
                "overrides": {
                    "if": {"after": false},
                    "for": {"after": false},
                    "while": {"after": false},
                    "switch": {"after": false}
                }
        
            }
        ],
        "eol-last": ["error", "always"],
        "no-unused-vars": [
            "error",
            {
                "argsIgnorePattern": "^_",
                "varsIgnorePattern": "^_"
            }
        ],
        "no-useless-escape": "off",
        "no-cond-assign": "off",
        "no-case-declarations": "off"
    }
}
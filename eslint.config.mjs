import jest from "eslint-plugin-jest"
import js from "@eslint/js"
import stylisticJs from "@stylistic/eslint-plugin-js"

export default [
  {
    // eslint config is very unintuitive; they will match an js file in any
    // directory by default and you can only expand this;
    // moreover, to have a global ignore, it must be specified without
    // any other key as a separate object...
    ignores: [
      "integration_test/",
      "installer/",
      "doc/",
      "deps/",
      "coverage/",
      "priv/",
      "tmp/",
      "test/"
    ],
  },
  {
    ...js.configs.recommended,

    plugins: {
      jest,
      "@stylistic/js": stylisticJs
    },

    languageOptions: {
      globals: {
        ...jest.environments.globals.globals,
        global: "writable",
      },

      ecmaVersion: 12,
      sourceType: "module",
    },

    rules: {
      "@stylistic/js/indent": ["error", 2, {
        SwitchCase: 1,
      }],
      
      "@stylistic/js/linebreak-style": ["error", "unix"],
      "@stylistic/js/quotes": ["error", "double"],
      "@stylistic/js/semi": ["error", "never"],
      
      "@stylistic/js/object-curly-spacing": ["error", "never", {
        objectsInObjects: false,
        arraysInObjects: false,
      }],
      
      "@stylistic/js/array-bracket-spacing": ["error", "never"],
      
      "@stylistic/js/comma-spacing": ["error", {
        before: false,
        after: true,
      }],
      
      "@stylistic/js/computed-property-spacing": ["error", "never"],
      
      "@stylistic/js/space-before-blocks": ["error", {
        functions: "never",
        keywords: "never",
        classes: "always",
      }],
      
      "@stylistic/js/keyword-spacing": ["error", {
        overrides: {
          if: {
            after: false,
          },
      
          for: {
            after: false,
          },
      
          while: {
            after: false,
          },
      
          switch: {
            after: false,
          },
        },
      }],
      
      "@stylistic/js/eol-last": ["error", "always"],
      
      "no-unused-vars": ["error", {
        argsIgnorePattern: "^_",
        varsIgnorePattern: "^_",
      }],
      
      "no-useless-escape": "off",
      "no-cond-assign": "off",
      "no-case-declarations": "off",
    },
  }]

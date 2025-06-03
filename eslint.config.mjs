import jest from "eslint-plugin-jest"
import js from "@eslint/js"
import stylistic from "@stylistic/eslint-plugin"

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
      "@stylistic": stylistic
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
      "@stylistic/indent": ["error", 2, {
        SwitchCase: 1,
      }],
      
      "@stylistic/linebreak-style": ["error", "unix"],
      "@stylistic/quotes": ["error", "double"],
      "@stylistic/semi": ["error", "never"],
      
      "@stylistic/object-curly-spacing": ["error", "never", {
        objectsInObjects: false,
        arraysInObjects: false,
      }],
      
      "@stylistic/array-bracket-spacing": ["error", "never"],
      
      "@stylistic/comma-spacing": ["error", {
        before: false,
        after: true,
      }],
      
      "@stylistic/computed-property-spacing": ["error", "never"],
      
      "@stylistic/space-before-blocks": ["error", {
        functions: "never",
        keywords: "never",
        classes: "always",
      }],
      
      "@stylistic/keyword-spacing": ["error", {
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
      
      "@stylistic/eol-last": ["error", "always"],
      
      "no-unused-vars": ["error", {
        argsIgnorePattern: "^_",
        varsIgnorePattern: "^_",
      }],
      
      "no-useless-escape": "off",
      "no-cond-assign": "off",
      "no-case-declarations": "off",
    },
  }]

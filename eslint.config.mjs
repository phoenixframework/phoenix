import jest from "eslint-plugin-jest";
import js from "@eslint/js";
import globals from "globals";
import tseslint from "typescript-eslint";

export default tseslint.config([
  {
    // eslint config is very unintuitive; they will match an js file in any
    // directory by default and you can only expand this;
    // moreover, to have a global ignore, it must be specified without
    // any other key as a separate object...
    ignores: [
      "assets/dist/",
      "integration_test/",
      "installer/",
      "doc/",
      "deps/",
      "coverage/",
      "priv/",
      "tmp/",
      "test/",
    ],
  },
  {
    extends: [js.configs.recommended, ...tseslint.configs.recommended],

    plugins: {
      jest,
    },

    languageOptions: {
      globals: {
        ...globals.browser,
        ...jest.environments.globals.globals,
        global: "writable",
      },

      ecmaVersion: 12,
      sourceType: "module",
    },

    rules: {
      "@typescript-eslint/no-unused-vars": [
        "error",
        {
          argsIgnorePattern: "^_",
          varsIgnorePattern: "^_",
        },
      ],

      "@typescript-eslint/no-unused-expressions": "off",
      "@typescript-eslint/no-explicit-any": "off",
    },
  },
]);

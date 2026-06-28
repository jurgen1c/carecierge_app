import js from "@eslint/js";

export default [
  {
    ignores: [
      "app/assets/builds/**",
      "coverage/**",
      "node_modules/**",
      "public/assets/**",
      "tmp/**"
    ]
  },
  js.configs.recommended,
  {
    files: [ "app/javascript/**/*.js", "bun.config.js" ],
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module",
      globals: {
        AggregateError: "readonly",
        Bun: "readonly",
        console: "readonly",
        document: "readonly",
        process: "readonly",
        window: "readonly"
      }
    },
    rules: {
      "no-unused-vars": [ "error", { argsIgnorePattern: "^_" } ]
    }
  }
];

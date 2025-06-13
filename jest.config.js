/*
 * For a detailed explanation regarding each configuration property, visit:
 * https://jestjs.io/docs/configuration
 */

module.exports = {
  // Automatically clear mock calls and instances between every test
  clearMocks: true,

  // Indicates which provider should be used to instrument code for coverage
  coverageProvider: "v8",

  // The paths to modules that run some code to configure or set up the testing environment before each test
  setupFiles: [
    // "<rootDir>/setupTests.js"
  ],

  // The test environment that will be used for testing
  testEnvironment: "jest-environment-jsdom",
  
  testEnvironmentOptions: {
    url: "https://example.com"
  },

  // The regexp pattern or array of patterns that Jest uses to detect test files
  testRegex: "/assets/test/.*_test\\.js$",
}

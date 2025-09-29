Feature: SSL Configuration for BeatMap Backend
  As a BeatMap system administrator
  I want to configure SSL/HTTPS settings properly
  So that the application can run securely in different environments

  Background:
    Given the BeatMap backend application is initializing
    And SSL configuration is being loaded

  @ssl @configuration
  Scenario: SSL Settings Initialization in Development Environment
    Given the environment is set to "development"
    And SSL is disabled for development
    When the SSL settings are initialized
    Then the SSL should be disabled
    And HTTPS redirection should be disabled
    And HSTS should be disabled
    And the CORS origins should include localhost

  @ssl @configuration
  Scenario: SSL Settings Initialization in Production Environment
    Given the environment is set to "production"
    And SSL is enabled for production
    When the SSL settings are initialized
    Then the SSL should be enabled
    And HTTPS redirection should be enabled
    And HSTS should be enabled with preload
    And the CORS origins should only include secure origins

  @ssl @security-headers
  Scenario: HSTS Header Generation
    Given SSL settings are configured for production
    And HSTS is enabled with max age 31536000 seconds
    And HSTS includes subdomains and preload
    When the HSTS header is generated
    Then the header should contain "max-age=31536000"
    And the header should contain "includeSubDomains"
    And the header should contain "preload"

  @ssl @security-headers
  Scenario: CSP Header Generation
    Given SSL settings are configured
    And CSP is enabled
    When the CSP header is generated
    Then the header should contain "default-src 'self'"
    And the header should contain "script-src 'self'"
    And the header should contain "style-src 'self' 'unsafe-inline'"
    And the header should contain "img-src 'self' data: https:"

  @ssl @validation
  Scenario: SSL Certificate Path Validation
    Given SSL is enabled
    When an invalid certificate path is provided
    Then a warning should be logged
    And the SSL settings should still be valid

  @ssl @validation
  Scenario: Environment Variable Parsing
    Given environment variables are set
    When boolean SSL settings are parsed from strings
    Then "true" should be parsed as boolean True
    And "false" should be parsed as boolean False
    And "1" should be parsed as boolean True
    And "0" should be parsed as boolean False
Feature: Simple SSL Configuration
  As a developer
  I want to configure SSL settings
  So that the application can run securely

  Scenario: SSL disabled by default
    Given SSL settings are initialized
    When no SSL configuration is provided
    Then SSL should be disabled
    And the environment should be development

  Scenario: SSL enabled in production
    Given the environment is set to production
    When SSL is enabled
    Then SSL should be enabled
    And HTTPS should be enforced
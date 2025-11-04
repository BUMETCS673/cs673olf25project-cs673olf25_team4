Feature: Security Middleware for HTTPS Support
  As a BeatMap system administrator
  I want security middleware to handle HTTPS redirection and security headers
  So that the application maintains proper security standards

  Background:
    Given the BeatMap backend application is running
    And security middleware is enabled

  @middleware @https-redirection
  Scenario: HTTPS Redirection in Production
    Given the environment is "production"
    And HTTPS enforcement is enabled
    When a client makes an HTTP request to "/api/concerts"
    Then the response should redirect to HTTPS
    And the response status should be 307

  @middleware @https-redirection
  Scenario: Health Check Bypass for HTTPS Redirection
    Given the environment is "production"
    And HTTPS enforcement is enabled
    When a client makes an HTTP request to "/health"
    Then the response should not redirect to HTTPS
    And the response status should be 200

  @middleware @security-headers
  Scenario: Security Headers Addition
    Given security headers middleware is active
    When a client makes any request
    Then the response should include security headers:
      | Header                   | Value                |
      | X-Content-Type-Options   | nosniff              |
      | X-Frame-Options          | DENY                 |
      | X-XSS-Protection        | 1; mode=block        |
      | Referrer-Policy         | strict-origin-when-cross-origin |

  @middleware @cors
  Scenario: CORS Configuration in Development
    Given the environment is "development"
    And CORS origins include localhost
    When a client makes a preflight request from "http://localhost:3000"
    Then the CORS headers should allow the origin
    And the Access-Control-Allow-Origin header should be set

  @middleware @cors
  Scenario: CORS Configuration in Production
    Given the environment is "production"
    And CORS origins are restricted to secure domains
    When a client makes a preflight request from "http://malicious-site.com"
    Then the CORS headers should reject the origin
    And no Access-Control-Allow-Origin header should be set

  @middleware @rate-limiting
  Scenario: Rate Limiting for API Endpoints
    Given rate limiting is enabled
    When a client makes multiple rapid requests to "/api/concerts"
    Then the first requests should be processed normally
    And subsequent requests should be rate limited
    But health check requests should not be rate limited

  @middleware @logging
  Scenario: Request Logging for Security Monitoring
    Given request logging middleware is active
    When any request is processed
    Then the request details should be logged
    And the log should include timestamp, method, path, and response time
    And sensitive information should be redacted from logs
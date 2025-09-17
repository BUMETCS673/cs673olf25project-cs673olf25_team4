
---

# Project Security Guidelines

This document outlines security best practices for working with **Python** and **FastAPI**, recommended GitHub Actions, and team-wide security policies to ensure our project remains secure.

---

## 1. FastAPI Security Best Practices

* **Authentication & Authorization**

  * Use OAuth2 with JWT tokens or a trusted provider (e.g., Auth0, Okta).
  * Apply **role-based access control (RBAC)** or **attribute-based access control (ABAC)**.
  * Never expose sensitive endpoints without authentication.

* **Input Validation**

  * Always use **Pydantic models** for request validation.
  * Sanitize query parameters and path variables.

* **Data Protection**

  * Store passwords using **bcrypt** or **argon2** (never plaintext).
  * Use HTTPS/TLS in production.
  * Use environment variables or a secrets manager for API keys and database credentials.

* **Rate Limiting & Throttling**

  * Protect against brute force and DDoS attacks (e.g., `slowapi`, API Gateway).

* **Headers & CORS**

  * Set strict security headers (`Strict-Transport-Security`, `X-Frame-Options`, `Content-Security-Policy`).
  * Configure CORS properly (avoid `*` in production).

* **Error Handling**

  * Do not leak stack traces or internal errors in responses.
  * Return generic error messages for untrusted clients.

---

## 2. General Python Security Best Practices

* **Dependencies**

  * Pin versions in `requirements.txt` or `poetry.lock`.
  * Run `pip install --require-hashes` to prevent dependency tampering.
  * Regularly scan for vulnerabilities (`pip-audit`, `safety`).

* **Secrets Management**

  * Never hardcode secrets in source code.
  * Use `.env` files (with `.gitignore`) or secret managers (AWS Secrets Manager, Vault).

* **Code Safety**

  * Avoid `eval()` and `exec()`.
  * Use `subprocess.run(..., shell=False)` instead of `os.system`.
  * Validate and sanitize all external input.

* **Serialization**

  * Avoid `pickle` for untrusted data.
  * Prefer `json` or `pydantic`.

* **Logging**

  * Never log sensitive data (passwords, tokens).
  * Use structured logging for traceability.

* **Least Privilege**

  * Run applications with minimal permissions.
  * Use containerization (Docker) with restricted privileges.

---

## 3. Free GitHub Actions for Security

Add these GitHub Actions workflows to `.github/workflows/`:

* **Dependency Security**

  * [Dependabot](https://docs.github.com/en/code-security/dependabot) – Automated dependency updates.
  * [pip-audit Action](https://github.com/pypa/pip-audit) – Detects known vulnerabilities in dependencies.

* **Static Analysis**

  * [Bandit Action](https://github.com/marketplace/actions/bandit-python-security-checks) – Python security linter.
  * [Semgrep Action](https://github.com/marketplace/actions/semgrep-action) – Finds security issues via patterns.

* **Secrets Scanning**

  * [GitHub Advanced Security (Free for Public Repos)](https://docs.github.com/en/code-security/secret-scanning) – Detects API keys and secrets in commits.
  * [Gitleaks Action](https://github.com/zricethezav/gitleaks-action) – Additional secret detection.

* **Code Quality**

  * [Flake8](https://github.com/marketplace/actions/flake8-action) – Linting and style checks.
  * [mypy](https://github.com/marketplace/actions/mypy) – Type safety.

---

## 4. Free Python Static Analysis Tools

* **[Bandit](https://bandit.readthedocs.io/)** – Finds common security issues in Python code.
* **[Semgrep](https://semgrep.dev/)** – Pattern-based static analysis for security and code quality.
* **[Safety](https://pyup.io/safety/)** – Checks dependencies against vulnerability databases.
* **[pip-audit](https://github.com/pypa/pip-audit)** – Scans for known vulnerabilities in dependencies.
* **[Pylint](https://pylint.pycqa.org/)** – General static analysis (detects bugs, bad practices).
* **[mypy](http://mypy-lang.org/)** – Type checking to prevent runtime errors.

---

## 5. Project Security Guidelines for All Team Members

All contributors must follow these practices:

1. **Code & Dependencies**

   * Always run static analysis (`bandit`, `flake8`, `mypy`) before committing. -> The CI/CD Pipeline and Security Checks GitHub Actions will perform these actions on pushes and pull requests.
   * Do not add dependencies without approval.
   * Update dependencies regularly and address security alerts.

2. **Secrets Management**

   * Never commit API keys, passwords, or certificates.
   * Use environment variables or secret managers.
   * Rotate credentials periodically.

3. **Git Hygiene**

   * Use clear, descriptive commit messages.
   * Review PRs for security implications.
   * Use development branches for task implementations, ***never commit something directly to main.***
   * Use .gitignore for sensitive files.


4. **Secure Development**

   * Validate **all user input**.
   * Follow the **principle of least privilege** in code and infrastructure.
   * Ensure error messages do not leak sensitive information.

5. **Incident Response**

   * If a vulnerability is found, report it immediately.
   * Document all fixes in the security changelog.

---

By following this guide, we help ensure that our FastAPI + Python project remains **secure, maintainable, and compliant with security best practices**.

---

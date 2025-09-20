# SECURITY CHANGELOG

This file tracks **security-related changes and decisions** in the project.  
Add an entry whenever a change impacts security (e.g. fixes, upgrades, policies).

---

## How to Use
- Record entries in **reverse chronological order** (newest first).
- Include: **Date**, **Change/Decision**, **Reason**, and (optional) **Who** made it.

---

## Entries

### 2025-09-18
- **Added:** bandit.yaml to allow assert to be in test files
  **Reason:** Assert statements are often useful for test suites
  **Who**: Michael Laszlo (Security Leader)

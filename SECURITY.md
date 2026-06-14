# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.3.x   | ✅        |
| < 1.3   | ❌        |

## Reporting a Vulnerability

ShuttleX takes security seriously. If you discover a security vulnerability, 
please do **not** open a public GitHub issue.

Instead, please report it via **GitHub Private Vulnerability Reporting**:
👉 [Report a vulnerability](https://github.com/DasDuo/ShuttleX/security/advisories/new)

Please include:
- A description of the vulnerability
- Steps to reproduce
- Potential impact
- Your suggested fix (optional)

## Response Process

- You will receive an acknowledgement within **72 hours**
- We aim to release a fix within **14 days** for critical issues
- You will be credited in the release notes (unless you prefer to stay anonymous)

## Scope

Particularly relevant for ShuttleX:
- SSH credential handling
- Config file access (~/.ssh/config)
- Terminal command injection via server names or custom commands

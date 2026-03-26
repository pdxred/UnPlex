# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in UnPlex, **please do not open a public issue.**

Instead, use GitHub's private vulnerability reporting:

1. Go to the [Security tab](https://github.com/pdxred/UnPlex/security) of this repository
2. Click **"Report a vulnerability"**
3. Provide a description of the issue, steps to reproduce, and any relevant details

I will acknowledge your report within 72 hours and work with you to understand and address the issue.

## Scope

UnPlex is a Roku BrightScript application that communicates with a user's own Plex Media Server. Security concerns relevant to this project include:

- **Authentication token handling** — Plex OAuth tokens stored in Roku's registry
- **Network communication** — HTTPS enforcement for PMS and plex.tv API calls
- **Media deletion** — The delete feature permanently removes files from the Plex server's disk
- **Debug log export** — Exported logs should not contain authentication tokens

## Supported Versions

Only the latest release is supported with security updates.

| Version | Supported |
|---------|-----------|
| 1.3.x   | ✅        |
| < 1.3   | ❌        |

# Debug Log Collection Guide

When reporting a bug, debug logs help the team diagnose the issue. UnPlex provides two methods to collect logs: the **in-app Export Logs** button and **telnet console** access.

## Method 1: In-App Export Logs (Recommended)

The simplest way to collect logs — no extra tools needed, just a web browser.

### Steps

1. **Reproduce the issue** in UnPlex so the relevant log entries are captured.
2. Navigate to **Settings** (the gear icon in the sidebar).
3. Select **Export Logs** from the settings menu.
4. A confirmation dialog will appear showing the file path.
5. Open a web browser on any device on the same network as your Roku.
6. Navigate to `http://<roku-ip>/tmpfs/unplex_debug.log`
   - Replace `<roku-ip>` with your Roku's IP address (found in Roku Settings → Network → About).
   - Your Roku must be in [developer mode](../CONTRIBUTING.md#enable-developer-mode-on-your-roku) for the dev web server to be accessible.
7. Save or copy the log contents and attach them to your bug report.

### What Gets Exported

The Export Logs function writes the in-memory log buffer to `tmp:/unplex_debug.log`. The buffer holds the most recent **500 log entries** in a ring buffer — older entries are evicted as new ones arrive. Each entry includes:

- ISO 8601 timestamp
- Log level (`EVENT` or `ERROR`)
- Message describing the action or failure

### Troubleshooting

- **"No log data available"** — The app hasn't logged anything yet. Use the app for a while (navigate screens, play content) and try again.
- **Can't access the URL** — Ensure your Roku is in developer mode and your computer is on the same local network. The dev web server runs on port 80 of the Roku device.
- **Logs don't cover the issue** — The buffer only holds 500 entries. Export logs immediately after reproducing the bug for the best results.

## Method 2: Telnet Console (Real-Time)

For developers or advanced users who want to see log output in real time as the app runs.

### Prerequisites

- Your Roku must be in [developer mode](../CONTRIBUTING.md#enable-developer-mode-on-your-roku).
- A telnet client on your computer (built into macOS/Linux; Windows users can use PuTTY or enable the Telnet Client feature).

### Steps

1. Open a terminal or telnet client.
2. Connect to your Roku on **port 8085**:
   ```
   telnet <roku-ip> 8085
   ```
   Replace `<roku-ip>` with your Roku's IP address.
3. You will see real-time console output from the app, including all `LogEvent()` and `LogError()` messages.
4. **Reproduce the issue** while the telnet session is open.
5. Copy the relevant console output and attach it to your bug report.

### Tips

- Port **8085** is the BrightScript debug console. Other useful ports:
  - **8080** — SceneGraph debug server (performance profiling)
  - **80** — Dev web server (file access, package install)
- The telnet console shows **all** `print` output from the app, including the formatted `[timestamp] [LEVEL] message` lines from the logger.
- To capture a long session, redirect output to a file:
  ```bash
  telnet <roku-ip> 8085 | tee unplex_debug_session.log
  ```

## Which Method Should I Use?

| Scenario | Recommended Method |
|----------|-------------------|
| Quick bug report — just need recent logs | **Export Logs** (in-app) |
| Investigating intermittent issues in real time | **Telnet** |
| Crash or freeze — app becomes unresponsive | **Telnet** (logs stream before crash) |
| Non-technical user reporting a bug | **Export Logs** (in-app) |
| Profiling performance or timing issues | **Telnet** (real-time timestamps) |

## Including Logs in a Bug Report

When filing a [bug report](https://github.com/pdxred/UnPlex/issues/new?template=bug-report.yml), paste the log output into the **Debug Logs** field. If the log file is large, attach it as a file instead of pasting inline. Always include:

1. The **steps you took** to reproduce the issue.
2. The **time** when the issue occurred (so the relevant log lines can be located).
3. Your **Roku model** and **OS version** — different devices may produce different log output.

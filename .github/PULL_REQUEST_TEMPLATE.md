## Description

<!-- Describe your changes in detail. What does this PR do and why? -->

## Related Issues

<!-- Link any related issues: Fixes #123, Relates to #456 -->

## Type of Change

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Refactor (code restructuring without behavior change)
- [ ] Documentation (docs, comments, or README updates)
- [ ] Chore (build config, CI, dependency updates)

## Checklist

- [ ] I have tested this on a real Roku device
- [ ] Roku model(s) tested: <!-- e.g. Roku Ultra 4800, TCL 6-Series -->
- [ ] `npm run build` completes with zero errors
- [ ] `npm run lint` passes with no new warnings
- [ ] No BusySpinner usage (causes firmware SIGSEGV — use LoadingSpinner instead)
- [ ] No hardcoded credentials or server URIs in committed code
- [ ] All HTTP requests run in Task nodes (no `roUrlTransfer` on render thread)
- [ ] Registry writes call `.Flush()` after every write
- [ ] New components follow the naming conventions in CONTRIBUTING.md
- [ ] Logging uses `LogEvent()` / `LogError()` — no raw `print` statements

## Testing

<!-- Describe how you tested your changes. Include specific screens, flows, or scenarios. -->

## Screenshots / Video

<!-- If applicable, add screenshots or video of the UI change. -->

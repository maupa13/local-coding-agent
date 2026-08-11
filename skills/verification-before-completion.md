---
name: verification-before-completion
---
Use before declaring work complete.

1. Inspect actual git status/diff.
2. Run the narrowest relevant deterministic tests/build/lint checks, then broader checks only when justified.
3. Never infer PASS from code inspection when an executable check exists.
4. Treat skipped/disabled tests, swallowed failures, and unverified generated artifacts as quality risks.
5. Map evidence to each acceptance criterion and name anything not verified.

---
name: systematic-debugging
---
Use for bugfix/hotfix work.

1. Reproduce or obtain concrete failure evidence before changing code.
2. Trace the failing path to a root cause; do not patch the first symptom.
3. Add a focused regression test when feasible before or with the fix.
4. Make the smallest root-cause correction.
5. Re-run the reproduction plus relevant broader checks.
6. If two materially identical repair attempts fail, stop repeating them and change the diagnostic approach.

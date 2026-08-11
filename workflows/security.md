# Workflow: Security Review / Fix

Purpose: identify or remediate concrete security risks in the requested scope.

- Inspect trust boundaries, authentication/authorization, input validation, secrets, deserialization, injection, file/path handling, SSRF, dependency/config exposure and auditability as applicable.
- Provide evidence and realistic exploit/failure conditions; avoid speculative noise.
- Preserve least privilege and secure defaults.
- For fixes, add regression/security tests where practical and avoid breaking compatibility silently.

Classify findings by impact/likelihood, provide exact remediation and verification. Do not expose real secrets found in the repository; redact them in reports.

## Workflow lock

ACTIVE WORKFLOW: /security

- This workflow is exclusive for this run and supersedes older workflow-specific instructions.
- Operate only on the repository fixed by the launcher. Never switch to another project/repository path during this run.
- Do not execute a different slash workflow inside this run. If another stage is needed, report it under `NEXT`; the launcher will run it as a fresh process.
- A denied tool/file is evidence, not a reason to repeat the same action. Use an allowed alternative or mark the item NOT VERIFIED.
- Follow the global execution/recovery/final-result contract and always finish with the mandatory `FINAL RESULT` block.

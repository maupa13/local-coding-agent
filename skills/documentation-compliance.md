---
name: documentation-compliance
---
Use when the task asks whether the repository matches documentation, specifications, requirements, or acceptance criteria.

This is a completion workflow, not a reconnaissance workflow. The user has already chosen the analysis focus by asking for documentation compliance. Do not stop after git status, an inventory, or a list of files. Do not ask the user what to inspect next when the requested scope is docs versus repository.

1. Read the relevant files under docs/ (or the explicitly supplied documentation scope) before judging implementation.
2. Enumerate concrete material requirements/claims. Group duplicates. Report contradictions between documents instead of silently resolving them.
3. For every material requirement, locate implementation evidence and test/verification evidence independently.
4. Use only these statuses: PASS, PARTIAL, FAIL, NOT VERIFIED, CONFLICT.
5. PASS requires direct implementation evidence and, where behavior is executable, relevant test/build/runtime evidence. Code inspection alone is insufficient when a test/check exists.
6. PARTIAL means a real subset exists but the documented behavior is incomplete. FAIL means evidence contradicts the requirement or a required implementation is absent. NOT VERIFIED means evidence could not actually be obtained. CONFLICT means sources disagree.
7. Do not modify project files in analysis/review mode.
8. BLOCKED is allowed only for a concrete unavailable source, denied access, or unavailable required tool/environment. Needing to read more repository files is never a blocker; read them now.
9. Finish with a section titled exactly COMPLIANCE MATRIX. Each material row/item must contain: requirement, status, implementation evidence, test/verification evidence, gap.
10. Include totals by status and highest-risk gaps after the matrix.
11. Cite repository-relative file paths and symbols. Never claim files/tests were inspected when they were not.
12. End with the mandatory FINAL RESULT report only after the compliance matrix is complete.

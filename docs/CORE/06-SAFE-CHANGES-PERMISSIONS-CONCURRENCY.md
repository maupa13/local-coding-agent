# Safe Changes, Permissions and Concurrency

## Core rule

Never destroy unrelated user changes.

## Change journal

Each write records:
- run;
- change set;
- path;
- before hash;
- after hash;
- patch/before image where practical.

## Forbidden routine recovery

Do not routinely use:
- git reset --hard;
- git clean -fd;
- force push;
- checkout-overwrite of dirty user files.

## Atomic write

```text
temporary write
→ flush/close
→ validate
→ atomic replacement where supported
```

## Dirty tree

Before implementation detect:
- tracked modified;
- staged;
- untracked;
- agent-owned changes.

## Rollback

Rollback only the agent-owned delta.

If file diverged after agent write:
- stop auto rollback;
- mark conflict;
- preserve data.

## Project boundary

Default:
- project reads/writes only;
- external write rejected;
- symlink/junction escape prevented.

## Permissions

Suggested profiles:
- read;
- code;
- project;
- trusted.

Destructive Git/system commands require elevated explicit policy.

## Dependency files

Changes to:
- pom.xml;
- build.gradle;
- package.json;
- requirements;
- lock files

should follow dependency opt-in policy.

## Concurrency

One write-capable run per repository/worktree.

Lock records:
- PID;
- run ID;
- start time;
- project;
- mode.

## Secrets

Protect/redact:
- `.env`;
- private keys;
- cloud credentials;
- certificates;
- configured production secrets.

## Acceptance

- user dirty changes survive failures;
- simultaneous writers are blocked;
- stale lock handling is safe;
- secrets do not appear unredacted in evidence;
- outside-project write attempts fail.

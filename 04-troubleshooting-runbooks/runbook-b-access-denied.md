# Runbook B — "User Locked Out / Access Denied to Shared Drive"

> **Version:** v1.0 · **Date:** 2026-11-24 · **Owner:** IT Support · **Tier:** 1
> **Typical call:** "It says access denied" or "my account is locked."

## Symptom

User cannot log in, or cannot open a shared folder they believe they should access. Three distinct causes look identical to the user — diagnose before touching anything:

1. **Expired password** (90-day max age policy)
2. **Account lockout** (5 failed attempts, 30-minute lockout)
3. **Permission mismatch** (they were never granted, or lost, access to that share)

## Tier-1 Differentiation

| Question | Check (Windows) | Points to |
|---|---|---|
| Does login itself fail? | Attempt login: message says "password expired" or account disabled? | Expired password → reset via their `username-adm` account or admin reset; set **new** password |
| Is the account locked? | Event Viewer → Security → filter **Event ID 4740** (lockout) — shows source machine too; or `net user <user>` → "Account active / Lockout" | Lockout → wait 30 min or admin-unlock; investigate why attempts failed (wrong password manager entry? phishing?) |
| Does login work but folder is denied? | `whoami /groups` — is the user in the right `GRP-*` group? Then `icacls "C:\Corp\<share>"` — does their group appear? | Permission mismatch → compare against the [RBAC matrix](../02-identity-and-access/rbac-matrix.md) |
| Which access exactly? | Explorer → folder Properties → Security → Advanced → **Effective Access** → select the user | Authoritative per-user verdict for the ticket |

Linux equivalents: `id <user>` / `groups` (membership), `ls -ld <path>` + `getfacl <path>` (permissions), `/var/log/auth.log` (sudo/auth failures).

## Resolution

| Cause | Fix |
|---|---|
| Expired password | Reset; hand over via two channels per [JML policy §4](../02-identity-and-access/jml-policy.md#4-onboarding-checklist--10-points-target--15-minutes) |
| Lockout | Unlock after verifying the attempts weren't an attack (check 4740 source); reset password if user forgot it |
| Missing group membership | Add to the correct `GRP-*` group per the matrix — never grant to the individual directly |
| Matrix says "No access" but user demands it | Do **not** override; route to the data owner for a documented access decision, then apply via the matrix |

## Root-Cause Prevention

- The RBAC matrix is the single source of truth — every grant is a matrix edit plus a group change, so drift can't accumulate.
- Role moves trigger the [Mover process](../02-identity-and-access/jml-policy.md#6-mover-process-department-change) — most "access denied" tickets after transfers come from skipped mover steps.
- Monthly review: `net localgroup <GRP>` on each group against current staff list.

## Escalation to Tier-2

- Lockout source machine is **not** the user's workstation (4740 from an unknown host) → possible credential compromise: treat as a security event, reset credentials, notify Security.
- Repeated permission drift → audit group membership changes (Event 4728/4732 add-to-group events) to find what's editing groups.

# RBAC Permission Matrix

> **Version:** v1.0 · **Date:** 2026-11-24 · **Owner:** IT Support · **Scope:** shared resources on Savannah Logistics Ltd. endpoints

## 1. Principle

Access is **deny-by-default**: no user can open any shared resource unless an explicit grant gives their department group the right level. Permission is granted to **groups, never individuals** — the matrix below is the single source of truth, and membership is controlled by the [JML policy](jml-policy.md).

## 2. Departmental Groups

| Group | Example members | Purpose |
|---|---|---|
| `GRP-Finance` | `awanjiru` (Alice Wanjiru) | Finance staff |
| `GRP-Operations` | operations staff | Operations/logistics staff |
| `GRP-ITSUPPORT` | `itsupport` | IT support team |
| `GRP-Interns` | interns | Interns — deliberately read-only everywhere |

All four groups are local groups on WIN-FIN01 (workgroup design — see [network-topology.md §6](../01-architecture/network-topology.md#6-design-notes)).

## 3. Resource Permission Matrix

| Resource | Finance | Operations | IT Support | Interns |
|---|---|---|---|---|
| `C:\Corp\Finance-Shared` | **Read/Write** | No access | Read | No access |
| `C:\Corp\Company-Templates` | Read | Read | **Read/Write** | Read |
| `C:\Corp\IT-Admin-Logs` | No access | No access | **Full control** | No access |

`SYSTEM` and `Administrators` retain full control on every resource for OS operation and break-glass maintenance.

## 4. Windows Implementation (NTFS ACLs)

NTFS is the enforcement layer (share permissions are left open at `Everyone: Read`; the ACLs below decide real access — standard practice that avoids double-gating confusion).

```bat
:: Finance-Shared — Finance writes, IT reads, everyone else denied
icacls "C:\Corp\Finance-Shared" /inheritance:r /grant:r "GRP-Finance:(OI)(CI)M" /grant:r "GRP-ITSUPPORT:(OI)(CI)RX" /grant:r "SYSTEM:(OI)(CI)F" /grant:r "Administrators:(OI)(CI)F"

:: Company-Templates — all departments read, IT maintains content
icacls "C:\Corp\Company-Templates" /inheritance:r /grant:r "GRP-Finance:(OI)(CI)RX" /grant:r "GRP-Operations:(OI)(CI)RX" /grant:r "GRP-ITSUPPORT:(OI)(CI)M" /grant:r "GRP-Interns:(OI)(CI)RX" /grant:r "SYSTEM:(OI)(CI)F" /grant:r "Administrators:(OI)(CI)F"

:: IT-Admin-Logs — IT only
icacls "C:\Corp\IT-Admin-Logs" /inheritance:r /grant:r "GRP-ITSUPPORT:(OI)(CI)F" /grant:r "SYSTEM:(OI)(CI)F" /grant:r "Administrators:(OI)(CI)F"
```

Legend: `(OI)(CI)` inherit to files and subfolders · `M` modify (read/write/delete) · `RX` read+execute · `F` full control. `/inheritance:r` strips inherited permissions so only explicit grants remain.

**Least privilege in action:** Finance can process company expenses but cannot open IT admin logs; interns can read templates but cannot modify or delete anything — verified in [T-04](../05-validation-evidence/test_results.md#t-04--rbac-folder-access-control).

## 5. Linux Access Model (SRV-LIN01)

| Subject | Access | Mechanism |
|---|---|---|
| `itsupport` | Remote administration | SSH key-pair only (no password auth at all), member of `sudo` group |
| Root | Never remotely | `PermitRootLogin no` — direct root SSH is impossible |
| Department users | No server login | No SSH keys deployed; UFW allows port 22 from the management subnet only |

## 6. Verification

| Check | Command (Windows) | Command (Linux) |
|---|---|---|
| Group membership of logged-in user | `whoami /groups` | `id`, `groups` |
| Effective ACL of a resource | `icacls "C:\Corp\IT-Admin-Logs"` | `ls -ld <path>`, `getfacl <path>` |
| Practical test | Log in as `awanjiru`, attempt to open `\\WIN-FIN01\IT-Admin-Logs` → denied | — |
| Effective Access audit view | Properties → Security → Advanced → Effective Access (select user) | — |

The practical test is captured as evidence in [T-04](../05-validation-evidence/test_results.md#t-04--rbac-folder-access-control).

# Joiner–Mover–Leaver (JML) Identity Policy

> **Version:** v1.0 · **Date:** 2026-11-24 · **Owner:** IT Support · **Scope:** all Savannah Logistics Ltd. workstations

## 1. Purpose & Scope

This policy governs the full lifecycle of every user identity: creation on hiring (**Joiner**), changes on role moves (**Mover**), and revocation on exit (**Leaver**). It exists because shared administrator passwords and ad-hoc account setup made it impossible to attribute actions to a person or to revoke access reliably.

## 2. Account Model & Separation of Duties

Every workstation user has **two distinct accounts** — one for daily work, one strictly for elevation:

| Account type | Naming | Used for | Can do | Cannot do |
|---|---|---|---|---|
| Day-to-day standard account | `first-initial + surname` (e.g., Alice Wanjiru → `awanjiru`) | Email, documents, department applications | Normal work tasks | Install software, alter system settings/registry, disable security tools, change firewall — every attempt triggers a UAC prompt requiring admin credentials (verified in [T-01](../05-validation-evidence/test_results.md#t-01--standard-user-privilege-boundary)) |
| Dedicated admin account | `username-adm` (e.g., `awanjiru-adm`) | Elevated maintenance only, when prompted | Install approved software, apply configuration changes | Daily work — no email, no browsing; typed only when elevation is required |
| IT support standard | `itsupport` | Day-to-day IT work | Standard tasks on IT workstation | — |
| IT support elevated | `it-adm` | Administration of servers/endpoints | Full administrative tasks | Shared with no one; individual accountability via logs |

**Rules:**

1. Administrator passwords are never shared — the `username-adm` model makes sharing pointless and auditable.
2. Admin accounts are excluded from daily workflows so phishing and malware running as the logged-in user gain no elevation.
3. Account naming is deterministic (`first-initial + surname`), so provisioning scripts and checklists never improvise.

## 3. Password & Lockout Policy

| Setting | Value |
|---|---|
| Minimum length | 12 characters |
| Maximum age | 90 days |
| Password history | Last 5 passwords cannot be reused |
| Account lockout threshold | 5 failed attempts |
| Lockout duration | 30 minutes |
| Screen lock | After 10 minutes of inactivity |
| Complexity | Enforced via local security policy |

Enforcement (Windows): `net accounts` settings applied by [windows-hardening.ps1](../06-lab-build/scripts/windows/windows-hardening.ps1) · (Linux): SSH key-only authentication replaces password-based remote login entirely; local sudo requires the user's own password.

## 4. Onboarding Checklist — 10 Points, Target ≤ 15 Minutes

| # | Step | Owner | Time |
|---|---|---|---|
| 1 | Create standard account (`first-initial + surname`) | IT Support | 1 min |
| 2 | Create dedicated `username-adm` admin account | IT Support | 1 min |
| 3 | Add account to department group (`GRP-Finance`, `GRP-Operations`, `GRP-ITSUPPORT`, `GRP-Interns`) | IT Support | 1 min |
| 4 | Verify share access per [RBAC matrix](rbac-matrix.md) | IT Support | 2 min |
| 5 | Verify hardening baseline compliance (all rows green in [windows-baseline](../03-hardening-baselines/windows-baseline.md)) | IT Support | 3 min |
| 6 | Configure mail and department applications | IT Support | 3 min |
| 7 | Confirm Defender active, firewall profiles ON, updates enabled | IT Support | 1 min |
| 8 | Hand over credentials through two separate channels (never both in the same message) | IT Support | 1 min |
| 9 | Record asset assignment (machine, accessories, serial) | IT Support | 1 min |
| 10 | Archive the completed checklist in IT records | IT Support | 1 min |

## 5. Offboarding Checklist — 5 Points, Executed Immediately

| # | Step | Owner | Deadline |
|---|---|---|---|
| 1 | Disable the account (both standard and `-adm`) — do not delete yet; disabled accounts preserve audit history | IT Support | Immediately on notice |
| 2 | Revoke remote access — remove from firewall-reachable groups, delete SSH keys from servers | IT Support | Immediately |
| 3 | Archive user files to IT records storage (retention per company policy) | IT Support | Same day |
| 4 | Reassign assets and update the asset register | IT Support | Same day |
| 5 | Document completion (who, when, what was returned) in IT records | IT Support | Same day |

**Principle:** a former employee must never retain a working credential past their last day.

## 6. Mover Process (Department Change)

1. Remove the account from the old department group.
2. Add to the new department group.
3. Re-verify share access against the [RBAC matrix](rbac-matrix.md) — old access gone, new access works.
4. Record the move (date, from, to) in IT records.

## 7. Audit & Evidence

- Account creation/modification events: Windows Event Viewer (4720 user created, 4722 enabled, 4725 disabled, 4740 lockout) — retained for audit.
- Linux identity events: `/var/log/auth.log` (sudo usage, SSH sessions).
- Completed on/offboarding checklists are the auditor's trail: every administrative action traces to a named person and a date.

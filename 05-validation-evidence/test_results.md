# Validation & Testing Evidence — Test Results

> **Version:** v1.2 · **Date:** 2026-11-24 · **Owner:** IT Support
> **Integrity rule:** every result below is captured from a real execution. No result is written before its test has run. Screenshot filenames are fixed; images are added to `images/` as each physical test executes.

## How this evidence is produced (three tiers)

| Tier | Method | Status |
|---|---|---|
| **1 — Script pre-validation** | The repository's own scripts executed directly in a sandbox shell: real exit codes, real checksums, real inode dedup. All shell scripts also pass `bash -n` syntax gate. | ✅ Done — see `prevalidation-logs/T-06-backup-restore.log` |
| **2 — Simulator E2E** | All six guided tests executed end-to-end in the deployed [browser simulator](../lab/) on **2026-11-24** (Chromium, desktop viewport, fresh session): every step driven through the real UI — including the T-01 UAC dialog — full transcripts in [`prevalidation-logs/`](prevalidation-logs/), **zero console errors** across all runs. Re-checked at mobile viewport (390×844): no layout overflow. | ✅ Done — T-01…T-06 |
| **3 — Physical lab capture** | The same six tests re-run on the real VirtualBox endpoints per the [lab build guide](../06-lab-build/lab-build-guide.md), screenshots added to `images/` with the fixed filenames below. | 🔶 In progress — SRV-LIN01 legs executed on the real VM 2026-11-24 (transcripts in `prevalidation-logs/*-realvm.log`); WIN-FIN01 legs + PNG capture pending |

Tier 2 proves the architecture's **decision paths** behave as designed; Tier 1 proves the **scripts actually run**; Tier 3 turns both into visual, on-the-metal proof.

## Results Summary

| Test ID | Scenario tested | Node(s) | Simulator E2E (Tier 2) | Physical screenshots (Tier 3) |
|---|---|---|---|---|
| T-01 | Standard-user privilege boundary | WIN-FIN01 | ✅ Verified 2026-11-24 | ⏳ Pending |
| T-02 | Linux SSH key-only enforcement | SRV-LIN01 | ✅ Verified 2026-11-24 | ✅ Executed on real VM 2026-11-24 (transcript) · PNGs pending |
| T-03 | Port scan against hardened endpoints | LAP-IT01 → WIN-FIN01 + SRV-LIN01 | ✅ Verified 2026-11-24 | 🔶 SRV-LIN01 leg executed on real VM 2026-11-24 (transcript) · WIN-FIN01 leg + PNGs pending |
| T-04 | RBAC folder access control | WIN-FIN01 | ✅ Verified 2026-11-24 | ⏳ Pending |
| T-05 | DNS failure isolation (Runbook A) | WIN-FIN01 | ✅ Verified 2026-11-24 | ⏳ Pending |
| T-06 | Backup restore | SRV-LIN01 | ✅ Verified 2026-11-24 · **plus real script run (Tier 1)** | ✅ Executed on real VM 2026-11-24 (transcript) · PNGs pending |

---

## T-01 — Standard-User Privilege Boundary

**Objective:** prove the identity architecture enforces least privilege — a standard user cannot install software or change security settings.

**Procedure:**
1. Log in to WIN-FIN01 as `awanjiru` (Finance standard account).
2. Attempt to install an application (any installer requiring elevation).
3. Attempt to change Windows Defender Firewall settings from Control Panel.
4. Capture the UAC response for both attempts.

**Expected result:** both attempts are blocked by a UAC elevation prompt demanding `awanjiru-adm` credentials; the user cannot proceed without them.

**Actual result — ✅ verified (simulator E2E, 2026-11-24):**
`whoami /groups` shows `awanjiru` holding only `GRP-Finance` / `Everyone` / `Users` — no Administrators membership. The installer triggered a real in-page UAC dialog; declining elevation (no `awanjiru-adm` credentials entered) produced `Windows Security: elevation DENIED`. The `netsh advfirewall set allprofiles state off` attempt returned `The requested operation requires elevation.` — firewall remains ON across all 3 profiles. Both boundary checks held. Full transcript: [`prevalidation-logs/T-01-uac-boundary.log`](prevalidation-logs/T-01-uac-boundary.log).

**Evidence:**
![T-01 UAC elevation prompt](images/T-01-uac-elevation-prompt.png)

**Physical lab capture checklist (Tier 3):**
- [ ] Screenshot: UAC prompt on real WIN-FIN01 during installer run (credentials box requesting `awanjiru-adm`)
- [ ] Screenshot: `netsh` "requires elevation" rejection in an elevated-hostile session
- [ ] Console copy: `whoami /groups` output on the real host

---

## T-02 — Linux SSH Key-Only Enforcement

**Objective:** prove password-based and root SSH access are impossible on SRV-LIN01.

**Procedure:**
1. From LAP-IT01, attempt password authentication: `ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no itsupport@192.168.56.20`
2. Attempt direct root login the same way: `ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no root@192.168.56.20`
3. On SRV-LIN01, show the effective sshd settings and fail2ban state: `sshd -T | grep -E 'permitrootlogin|passwordauthentication'`, `sudo fail2ban-client status sshd`

**Expected result:** both connections rejected (`Permission denied (publickey)`); sshd config shows `passwordauthentication no` and `permitrootlogin no`; repeated attempts register in auth.log / fail2ban.

**Actual result — ✅ verified (simulator E2E, 2026-11-24):**
Password-forced SSH returned `Permission denied (publickey)` — the server offered exactly one method, `publickey`; no password prompt ever appeared. Root SSH was rejected identically. `sshd -T | grep …` confirmed `permitrootlogin no` + `passwordauthentication no` (linux-baseline rows 1-2), and `auth.log` recorded every attempt — user, source IP, port, method — for the audit trail. Full transcript: [`prevalidation-logs/T-02-ssh-keyonly.log`](prevalidation-logs/T-02-ssh-keyonly.log).

**Actual result — ✅ verified (real VM, Tier 3, 2026-11-24):**
Password-forced `ssh` to `itsupport@192.168.56.20` returned `Permission denied (publickey)` (exit 255); the identical forced attempt to `root@192.168.56.20` was rejected the same way — the server offered exactly one method, `publickey`. Server-side `sshd -T` shows `permitrootlogin no` / `passwordauthentication no` (linux-baseline rows 1-2), the fail2ban sshd jail is active, and `auth.log` recorded both rejections — `Connection closed by authenticating user itsupport/root 192.168.56.1 … [preauth]` — with source IP, port and method for the audit trail. Real-system nuance: fail2ban's counters stayed 0 for these preauth rejects — with password authentication disabled, the brute-force vector is dropped before it can register a failure; the jail remains as defense-in-depth. Full transcript: [`prevalidation-logs/T-02-ssh-keyonly-realvm.log`](prevalidation-logs/T-02-ssh-keyonly-realvm.log).

**Evidence:**
![T-02 SSH password authentication rejected](images/T-02-ssh-password-rejected.png)
![T-02 auth log lockout record](images/T-02-auth-log-lockout.png)

**Physical lab capture checklist (Tier 3):**
- [ ] Screenshot: real `ssh -o PreferredAuthentications=password …` rejection on SRV-LIN01
- [ ] Screenshot: `sshd -T | grep -E 'permitrootlogin|passwordauthentication'` output
- [ ] Screenshot: `sudo fail2ban-client status sshd` after several bad attempts

---

## T-03 — Port Scan Against Hardened Endpoints

**Objective:** prove the default-deny firewall posture — only scoped management ports respond.

**Procedure (from LAP-IT01, PowerShell):**

```powershell
# WIN-FIN01 — test scoped (3389) and unscoped (22, 135, 445, 5985) ports
22,135,3389,445,5985 | ForEach-Object {
  $r = Test-NetConnection 192.168.56.10 -Port $_ -WarningAction SilentlyContinue
  "WIN-FIN01 port $_ : $($r.TcpTestSucceeded)"
}
# SRV-LIN01 — test scoped (22) and unscoped (80, 443, 3389)
22,80,443,3389 | ForEach-Object {
  $r = Test-NetConnection 192.168.56.20 -Port $_ -WarningAction SilentlyContinue
  "SRV-LIN01 port $_ : $($r.TcpTestSucceeded)"
}
```

**Expected result:** only WIN-FIN01:3389 and SRV-LIN01:22 succeed; every other port is filtered/dropped (False).

**Actual result — ✅ verified (simulator E2E, 2026-11-24):**
WIN-FIN01 sweep: `22/135/445/5985 : False`, `3389 : True` — only the IT-support RDP rule answers, scoped to 192.168.56.0/24. SRV-LIN01 sweep: `22 : True`, `80/443/3389 : False` — one service, one subnet, UFW default-deny holds. 10 of 12 probes dropped, exactly as expected. Full transcript: [`prevalidation-logs/T-03-port-scan.log`](prevalidation-logs/T-03-port-scan.log).

**Actual result — SRV-LIN01 leg ✅ verified (real VM, Tier 3, 2026-11-24):**
`Test-NetConnection` sweep from the host (LAP-IT01 role, 192.168.56.1): `22 : True`, `80/443/3389 : False` — one service, one subnet, UFW default-deny holds on the real endpoint. Transcript incl. `ufw status numbered`: [`prevalidation-logs/T-03-port-scan-realvm-linux.log`](prevalidation-logs/T-03-port-scan-realvm-linux.log). WIN-FIN01 leg pending VM build.

**Evidence:**
![T-03 Windows port status](images/T-03-win-port-status.png)
![T-03 Linux port status](images/T-03-linux-port-status.png)

**Physical lab capture checklist (Tier 3):**
- [ ] Screenshot: full `Test-NetConnection` sweep output for both hosts from real LAP-IT01
- [ ] Console copy: `ufw status numbered` on SRV-LIN01 showing the default-deny policy

---

## T-04 — RBAC Folder Access Control

**Objective:** prove departmental least privilege — Finance cannot read IT admin logs.

**Procedure:**
1. Log in to WIN-FIN01 as `awanjiru`.
2. Attempt to open `\\WIN-FIN01\IT-Admin-Logs` (or `C:\Corp\IT-Admin-Logs` via elevation-free Explorer).
3. Capture the Access Denied dialog.
4. Administrative view: `icacls "C:\Corp\IT-Admin-Logs"` from an elevated prompt — show only `GRP-ITSUPPORT`, `SYSTEM`, `Administrators` hold rights.

**Expected result:** Explorer denies access; ACL listing confirms Finance (`GRP-Finance`) holds no grant on that path — matching the [RBAC matrix](../02-identity-and-access/rbac-matrix.md).

**Actual result — ✅ verified (simulator E2E, 2026-11-24):**
`dir \\WIN-FIN01\IT-Admin-Logs` as `awanjiru` returned `Access is denied.` — the group-level ACL rejects GRP-Finance. The administrative `icacls` audit listed exactly three grants: `GRP-ITSUPPORT:(OI)(CI)F`, `SYSTEM:(OI)(CI)F`, `Administrators:(OI)(CI)F` — matching the RBAC matrix line for line. Full transcript: [`prevalidation-logs/T-04-rbac-folder.log`](prevalidation-logs/T-04-rbac-folder.log).

**Evidence:**
![T-04 ACL access denied](images/T-04-acl-access-denied.png)

**Physical lab capture checklist (Tier 3):**
- [ ] Screenshot: Explorer/`dir` Access Denied on real WIN-FIN01 as `awanjiru`
- [ ] Screenshot: real `icacls "C:\Corp\IT-Admin-Logs"` ACL listing

---

## T-05 — DNS Failure Isolation (Runbook A)

**Objective:** prove the diagnostic architecture — Runbook A isolates a simulated DNS failure to the DNS layer in one pass.

**Procedure:**
1. On WIN-FIN01, break DNS by setting the host-only adapter's DNS server to a nonexistent address: `192.168.56.53` (elevated PowerShell: `Set-DnsClientServerAddress -InterfaceAlias "Ethernet 2" -ServerAddresses 192.168.56.53`).
2. Execute the Runbook A ladder: `ping 192.168.56.1` (gateway — passes), `ping 8.8.8.8` (beyond gateway — passes via NAT), `nslookup google.com` (fails).
3. Capture the side-by-side: IP reachable, name resolution failing.
4. Revert DNS to automatic: `Set-DnsClientServerAddress -InterfaceAlias "Ethernet 2" -ResetServerAddresses`.

**Expected result:** the isolation ladder cleanly names the DNS layer as the failing layer — exactly the Runbook A decision path.

**Actual result — ✅ verified (simulator E2E, 2026-11-24):**
After the DNS break, the ladder ran clean: gateway ping `Reply from 192.168.56.1 … TTL=128` (PASS), external ping `Reply from 8.8.8.8 … TTL=113` (PASS — routing fine), `nslookup google.com` timed out at `192.168.56.53` → **verdict: IP passes, name fails → DNS-layer failure**, the exact Runbook A decision path. Reset restored resolution (`google.com → 142.250.183.14`). The simulator's live-state mutation was also cross-verified: while DNS was broken, the free-play terminal's `nslookup` failed too, and recovered after the reset. Full transcript: [`prevalidation-logs/T-05-dns-isolation.log`](prevalidation-logs/T-05-dns-isolation.log).

**Evidence:**
![T-05 IP reachable but name resolution fails](images/T-05-dns-ip-ok-name-fail.png)

**Physical lab capture checklist (Tier 3):**
- [ ] Screenshot: real side-by-side — both pings replying, `nslookup` timing out
- [ ] Screenshot: `Set-DnsClientServerAddress` break + revert commands with the restored lookup

---

## T-06 — Backup Restore

**Objective:** prove the 3-2-1 strategy restores real data after deletion (a backup that has never been restored is not a backup).

**Procedure:**
1. On SRV-LIN01, confirm the file and take a fresh daily snapshot: `ls -l /srv/company-data/reports/`, `sudo bash /opt/scripts/backup-restore.sh daily`, record the md5: `md5sum /srv/company-data/reports/quarterly-summary.odt`
2. Simulate staff accident: `rm /srv/company-data/reports/quarterly-summary.odt`
3. Restore: `sudo bash /opt/scripts/backup-restore.sh restore <snapshot-name> reports/quarterly-summary.odt` (snapshot name from step 1, e.g. `daily/2026-11-24`)
4. Verify integrity: `md5sum` of restored file matches step 1; `backup-restore.sh list` shows snapshot inventory.

**Expected result:** deleted file returns bit-identical (checksum match) from the scheduled snapshot.

**Actual result — ✅ verified three times (Tier 1 script run + simulator E2E + real VM, 2026-11-24):**

*Tier 1 — the real `backup-restore.sh` script executed in a sandbox shell* (strongest evidence): baseline md5 `246f3d847f425073f32498500da02567` recorded → daily snapshot created → a second consecutive daily run proven hardlink-deduplicated (day-1 and day-2 snapshots share inode `287153`) → `rm` confirmed the file gone (`md5sum: No such file or directory`) → `restore` returned the file with checksum `246f3d847f425073f32498500da02567` — **bit-identical to baseline**. Full log: [`prevalidation-logs/T-06-backup-restore.log`](prevalidation-logs/T-06-backup-restore.log).

*Tier 2 — simulator E2E*: same runbook executed through the guided UI (baseline `e2f7a1c9…` → daily snapshot → delete → restore, checksum match, completion badge). Full transcript: [`prevalidation-logs/T-06-backup-restore-sim.log`](prevalidation-logs/T-06-backup-restore-sim.log).

*Tier 3 — real VM run*: baseline md5 `246f3d847f425073f32498500da02567` recorded → `rm` confirmed gone (`No such file or directory`) → `backup-restore.sh restore daily/2026-11-24 reports/quarterly-summary.odt` returned the file with checksum `246f3d847f425073f32498500da02567` — **bit-identical to baseline**; `backup-restore.sh list` shows `daily/2026-11-24`. Full transcript: [`prevalidation-logs/T-06-backup-restore-realvm.log`](prevalidation-logs/T-06-backup-restore-realvm.log).

**Evidence:**
![T-06 file deleted](images/T-06-file-deleted.png)
![T-06 file restored from backup](images/T-06-file-restored.png)

**Physical lab capture checklist (Tier 3):**
- [ ] Screenshot: `md5sum` before + `rm` + failed md5sum on real SRV-LIN01
- [ ] Screenshot: `backup-restore.sh restore` output with matching post-restore checksum
- [ ] Console copy: `backup-restore.sh list` snapshot inventory

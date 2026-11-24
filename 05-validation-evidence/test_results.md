# Validation & Testing Evidence — Test Results

> **Version:** v1.0 · **Date:** 2026-11-24 · **Owner:** IT Support
> **Integrity rule:** every result below is captured from a real execution against the built lab. No result is written before its test has run. Screenshot filenames are fixed; images are added to `images/` as each test executes.

## Results Summary

| Test ID | Scenario tested | Node(s) | Status |
|---|---|---|---|
| T-01 | Standard-user privilege boundary | WIN-FIN01 | ⏳ Pending — capture in lab session |
| T-02 | Linux SSH key-only enforcement | SRV-LIN01 | ⏳ Pending — capture in lab session |
| T-03 | Port scan against hardened endpoints | LAP-IT01 → WIN-FIN01 + SRV-LIN01 | ⏳ Pending — capture in lab session |
| T-04 | RBAC folder access control | WIN-FIN01 | ⏳ Pending — capture in lab session |
| T-05 | DNS failure isolation (Runbook A) | WIN-FIN01 | ⏳ Pending — capture in lab session |
| T-06 | Backup restore | SRV-LIN01 | ⏳ Pending — capture in lab session |

---

## T-01 — Standard-User Privilege Boundary

**Objective:** prove the identity architecture enforces least privilege — a standard user cannot install software or change security settings.

**Procedure:**
1. Log in to WIN-FIN01 as `awanjiru` (Finance standard account).
2. Attempt to install an application (any installer requiring elevation).
3. Attempt to change Windows Defender Firewall settings from Control Panel.
4. Capture the UAC response for both attempts.

**Expected result:** both attempts are blocked by a UAC elevation prompt demanding `awanjiru-adm` credentials; the user cannot proceed without them.

**Actual result:** ⏳ Pending — capture in lab session

**Evidence:**
![T-01 UAC elevation prompt](images/T-01-uac-elevation-prompt.png)

---

## T-02 — Linux SSH Key-Only Enforcement

**Objective:** prove password-based and root SSH access are impossible on SRV-LIN01.

**Procedure:**
1. From LAP-IT01, attempt password authentication: `ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no itsupport@192.168.56.20`
2. Attempt direct root login the same way: `ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no root@192.168.56.20`
3. On SRV-LIN01, show the effective sshd settings and fail2ban state: `sshd -T | grep -E 'permitrootlogin|passwordauthentication'`, `sudo fail2ban-client status sshd`

**Expected result:** both connections rejected (`Permission denied (publickey)`); sshd config shows `passwordauthentication no` and `permitrootlogin no`; repeated attempts register in auth.log / fail2ban.

**Actual result:** ⏳ Pending — capture in lab session

**Evidence:**
![T-02 SSH password authentication rejected](images/T-02-ssh-password-rejected.png)
![T-02 auth log lockout record](images/T-02-auth-log-lockout.png)

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

**Actual result:** ⏳ Pending — capture in lab session

**Evidence:**
![T-03 Windows port status](images/T-03-win-port-status.png)
![T-03 Linux port status](images/T-03-linux-port-status.png)

---

## T-04 — RBAC Folder Access Control

**Objective:** prove departmental least privilege — Finance cannot read IT admin logs.

**Procedure:**
1. Log in to WIN-FIN01 as `awanjiru`.
2. Attempt to open `\\WIN-FIN01\IT-Admin-Logs` (or `C:\Corp\IT-Admin-Logs` via elevation-free Explorer).
3. Capture the Access Denied dialog.
4. Administrative view: `icacls "C:\Corp\IT-Admin-Logs"` from an elevated prompt — show only `GRP-ITSUPPORT`, `SYSTEM`, `Administrators` hold rights.

**Expected result:** Explorer denies access; ACL listing confirms Finance (`GRP-Finance`) holds no grant on that path — matching the [RBAC matrix](../02-identity-and-access/rbac-matrix.md).

**Actual result:** ⏳ Pending — capture in lab session

**Evidence:**
![T-04 ACL access denied](images/T-04-acl-access-denied.png)

---

## T-05 — DNS Failure Isolation (Runbook A)

**Objective:** prove the diagnostic architecture — Runbook A isolates a simulated DNS failure to the DNS layer in one pass.

**Procedure:**
1. On WIN-FIN01, break DNS by setting the host-only adapter's DNS server to a nonexistent address: `192.168.56.53` (elevated PowerShell: `Set-DnsClientServerAddress -InterfaceAlias "Ethernet 2" -ServerAddresses 192.168.56.53`).
2. Execute the Runbook A ladder: `ping 192.168.56.1` (gateway — passes), `ping 8.8.8.8` (beyond gateway — passes via NAT), `nslookup google.com` (fails).
3. Capture the side-by-side: IP reachable, name resolution failing.
4. Revert DNS to automatic: `Set-DnsClientServerAddress -InterfaceAlias "Ethernet 2" -ResetServerAddresses`.

**Expected result:** the isolation ladder cleanly names the DNS layer as the failing layer — exactly the Runbook A decision path.

**Actual result:** ⏳ Pending — capture in lab session

**Evidence:**
![T-05 IP reachable but name resolution fails](images/T-05-dns-ip-ok-name-fail.png)

---

## T-06 — Backup Restore

**Objective:** prove the 3-2-1 strategy restores real data after deletion (a backup that has never been restored is not a backup).

**Procedure:**
1. On SRV-LIN01, confirm the file and take a fresh daily snapshot: `ls -l /srv/company-data/reports/`, `sudo bash /opt/scripts/backup-restore.sh daily`, record the md5: `md5sum /srv/company-data/reports/quarterly-summary.odt`
2. Simulate staff accident: `rm /srv/company-data/reports/quarterly-summary.odt`
3. Restore: `sudo bash /opt/scripts/backup-restore.sh restore <snapshot-name> reports/quarterly-summary.odt` (snapshot name from step 1, e.g. `daily/2026-11-24`)
4. Verify integrity: `md5sum` of restored file matches step 1; `backup-restore.sh list` shows snapshot inventory.

**Expected result:** deleted file returns bit-identical (checksum match) from the scheduled snapshot.

**Actual result:** ⏳ Pending — capture in lab session

**Evidence:**
![T-06 file deleted](images/T-06-file-deleted.png)
![T-06 file restored from backup](images/T-06-file-restored.png)

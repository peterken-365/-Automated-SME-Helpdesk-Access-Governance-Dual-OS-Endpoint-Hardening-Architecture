# Windows Endpoint Hardening Baseline — WIN-FIN01

> **Version:** v1.0 · **Date:** 2026-11-24 · **Owner:** IT Support
> **Golden Standard rule:** a machine ships to an employee **only** when every row below verifies green. Implemented by [windows-hardening.ps1](../06-lab-build/scripts/windows/windows-hardening.ps1).

## 1. Baseline Compliance Table

| # | Control | Required setting | Verification method | Status |
|---|---|---|---|---|
| 1 | User Account Control (UAC) | `EnableLUA=1`, `ConsentPromptBehaviorAdmin=2` (prompt for consent on secure desktop) | `reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"` + practical elevation attempt | ⏳ |
| 2 | Account tier separation | Day-to-day standard user; `username-adm` for elevation only | `whoami /groups` as standard user — no Administrators membership | ⏳ |
| 3 | Malware protection | Defender: real-time + behavior monitoring + cloud MAPS enabled | `Get-MpComputerStatus` | ⏳ |
| 4 | Host firewall | All 3 profiles (Domain/Private/Public) ON; inbound default **Block**; outbound Allow | `Get-NetFirewallProfile` | ⏳ |
| 5 | Scoped inbound rules | RDP TCP 3389 and ICMPv4 echo allowed **only** from 192.168.56.0/24 | `Get-NetFirewallRule -DisplayName "Allow *"` + port scan | ⏳ |
| 6 | SMBv1 | Protocol disabled (legacy, exploited by WannaCry-class malware) | `Get-SmbServerConfiguration \| Select EnableSMB1Protocol` | ⏳ |
| 7 | Guest account | Disabled | `net user guest` → "Account active: No" | ⏳ |
| 8 | AutoRun/AutoPlay | Disabled on all drive types (`NoDriveTypeAutoRun=255`) — blocks USB-borne malware execution | `reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoDriveTypeAutoRun` | ⏳ |
| 9 | OS updates | Automatic (Windows Update), active hours configured to avoid disruption | Settings → Windows Update → history | ⏳ |
| 10 | Password & lockout policy | Min 12 chars, max age 90 days, history 5, lockout 5 attempts / 30 min | `net accounts` | ⏳ |
| 11 | Screen lock | Auto-lock after 10 minutes inactivity (`InactivityTimeoutSecs=600`) | `reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v InactivityTimeoutSecs` | ⏳ |
| 12 | Full-disk encryption (BitLocker) | Enabled on OS + data volumes; **recovery key escrowed** per §2 | `Get-BitLockerVolume` | ⏳ (design) |
| 13 | Remote access | RDP enabled for IT support, reachable **only** from management subnet | System Properties + `Get-NetFirewallRule` | ⏳ |

## 2. BitLocker Design & Recovery Key Escrow

Full-disk encryption protects data if a laptop is lost or stolen — the most common real-world breach path for SMEs.

**Design:**

1. BitLocker is enabled on the OS volume and every fixed data volume (XtsAes-256, used-space-only encryption for speed on first run).
2. TPM + PIN is the target protector on physical machines with TPM 2.0; VMs without a TPM use the BitLocker recovery-password protector instead.

**Recovery key escrow process (mandatory):**

1. At enablement, the 48-digit recovery key is **printed** and stored in a sealed envelope in the IT safe, AND saved as a text file to the IT-Admin-Logs share (IT-Support-only access per [RBAC matrix](../02-identity-and-access/rbac-matrix.md)).
2. The envelope is labeled with the machine's asset tag — never with the key itself in digital form on the same machine.
3. Recovery events (BitLocker lockout → key used) are logged in IT records: date, machine, who authorized, why.
4. Keys are rotated (re-encrypted with new key) after any recovery event or staff change on that machine.

**Lab note:** the VirtualBox VM has no TPM 2.0, so this row is verified as **design + escrow process** (`Get-BitLockerVolume` shows the mechanism); production rollouts enable it per-machine at provisioning time.

## 3. What This Baseline Prevents

| Threat | Blocked by |
|---|---|
| User installs cracked software carrying malware | Rows 1–2 (UAC + tier separation) |
| USB-dropped malware executes on insertion | Row 8 (AutoRun off) |
| Ransomware pivoting via legacy SMB | Row 6 (SMBv1 off) + row 3 (Defender) |
| Stolen laptop → data breach | Row 12 (BitLocker) |
| Ex-employee retains access | Row 10 password policy + [offboarding checklist](../02-identity-and-access/jml-policy.md#5-offboarding-checklist--5-points-executed-immediately) |
| External attack surface creep | Rows 4–5, 13 (default-deny + scoped rules) |

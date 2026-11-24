# Linux Server Hardening Baseline — SRV-LIN01

> **Version:** v1.0 · **Date:** 2026-11-24 · **Owner:** IT Support
> **Golden Standard rule:** the server enters service **only** when every row below verifies green. Implemented by [linux-hardening.sh](../06-lab-build/scripts/linux/linux-hardening.sh).

## 1. Baseline Compliance Table

| # | Control | Required setting | Verification method | Status |
|---|---|---|---|---|
| 1 | SSH key-only authentication | `PasswordAuthentication no`, `PubkeyAuthentication yes`, `KbdInteractiveAuthentication no` | `sshd -T \| grep -E 'passwordauthentication\|pubkeyauthentication\|kbdinteractiveauthentication'` | ⏳ |
| 2 | No direct root SSH | `PermitRootLogin no` | `sshd -T \| grep permitrootlogin` | ⏳ |
| 3 | Host firewall | UFW: default deny incoming, allow outgoing, TCP 22 from 192.168.56.0/24 **only** | `ufw status verbose` | ⏳ |
| 4 | Automated security updates | `unattended-upgrades` enabled (`20auto-upgrades` present) | `cat /etc/apt/apt.conf.d/20auto-upgrades` + `systemctl status unattended-upgrades` | ⏳ |
| 5 | Brute-force lockout | fail2ban sshd jail: 5 failures in 10 min → 30 min ban | `fail2ban-client status sshd` | ⏳ |
| 6 | Sudo restriction | Only `itsupport` / `it-adm` in the `sudo` group | `getent group sudo` | ⏳ |
| 7 | Least-privilege permissions | `/etc/ssh/sshd_config` = 600, `/root` = 700, `/home/*` = 750 | `stat -c '%a %n' /etc/ssh/sshd_config /root /home/*` | ⏳ |
| 8 | Audit logging | auth.log retained; SSH + sudo + fail2ban events reviewed weekly | `tail /var/log/auth.log` | ⏳ |

## 2. Control Rationale

| Control | Why it exists |
|---|---|
| Key-only SSH | Password authentication is the #1 brute-force target on any internet-reachable server. Cryptographic keys remove the attack class entirely — verified in [T-02](../05-validation-evidence/test_results.md#t-02--linux-ssh-key-only-enforcement) |
| No root SSH | Eliminates the single most-guessable account name; admins authenticate as themselves (accountability) and elevate with `sudo` |
| Default-deny firewall | The server exposes exactly one service (SSH) to exactly one subnet; everything else is invisible — verified in [T-03](../05-validation-evidence/test_results.md#t-03--port-scan-against-hardened-endpoints) |
| Unattended upgrades | Unpatched known CVEs are the cheapest attack vector; patches land without waiting for a human |
| fail2ban | Even key-only setups face log noise; ban-on-failure keeps logs clean and adds a second lockout layer |
| File permissions | Config files readable-only-by-root prevent local privilege escalation via sshd tampering |

## 3. Remote Access Workflow (IT Support)

1. Admin generates a dedicated Ed25519 key pair on LAP-IT01 (`ssh-keygen -t ed25519`).
2. The public key is installed on SRV-LIN01 for `itsupport` only.
3. All sessions run as `itsupport`; changes requiring root go through `sudo` — every elevation lands in `auth.log` with the invoking user's name.
4. Private keys never leave LAP-IT01 and are protected with a passphrase.

## 4. What This Baseline Prevents

| Threat | Blocked by |
|---|---|
| Password brute-force / credential stuffing | Rows 1, 5 |
| Direct root compromise from outside | Row 2 |
| Unauthorized service exposure | Row 3 (verified: only 22/tcp from mgmt subnet responds) |
| Missing vendor security patches | Row 4 |
| Local privilege escalation via config tampering | Rows 6–7 |
| Untraceable administrative actions | Row 8 + sudo accountability |

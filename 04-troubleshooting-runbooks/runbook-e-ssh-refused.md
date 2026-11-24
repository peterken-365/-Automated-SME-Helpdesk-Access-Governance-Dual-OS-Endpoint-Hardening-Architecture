# Runbook E — "Remote Support / SSH Connection Refused"

> **Version:** v1.0 · **Date:** 2026-11-24 · **Owner:** IT Support · **Tier:** 1
> **Typical call:** "I can't SSH into the server" or "RDP to a workstation won't connect."

## Symptom

Remote session to SRV-LIN01 (SSH) or WIN-FIN01 (RDP) is refused, times out, or errors. Five distinct causes live behind "connection refused."

## Tier-1 Isolation Steps

Start with the verbose client — it names the failing stage:

```bash
ssh -v itsupport@192.168.56.20
```

| Step | Layer | Check | Pass | Fail → |
|---|---|---|---|---|
| 1 | Reachability | `ping 192.168.56.20` from LAP-IT01 | Replies → network path fine | Wrong subnet/address conflict — verify target IP, check `arp -a` for duplicate MAC |
| 2 | Firewall (server side) | `sudo ufw status verbose` on SRV-LIN01 | `22/tcp ALLOW from 192.168.56.0/24` present | Rule missing → re-add scoped rule; NEVER open 0.0.0.0 |
| 3 | Service running | `systemctl status ssh` on SRV-LIN01 | `active (running)` | `sudo systemctl restart ssh`; check `journalctl -u ssh -n 50` for the start failure reason |
| 4 | Port actually bound | `ss -tlnp | grep :22` | sshd LISTEN on 0.0.0.0:22 (or scoped) | Config error in sshd — validate with `sshd -t` before restarting |
| 5 | Authentication | Verbose log reaches `Authentications that can continue: publickey` | Key offered and accepted | `Permission denied (publickey)` → key not installed for that user, wrong key, or passphrase prompt failed |

**Windows/RDP variant:** same ladder, substituted commands — `Test-NetConnection WIN-FIN01 -Port 3389` (replaces ping), `Get-NetFirewallRule -DisplayName "Allow RDP*"` (firewall), `Get-Service TermService` (service), System Properties → Remote tab (enabled?).

**Special case — "WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED":** STOP. This warning means the server's SSH host key differs from what you've seen before — it is either a rebuilt server (legitimate, verify out-of-band with the server owner) or a man-in-the-middle attack. Never blindly delete the `known_hosts` entry; verify first, then remove the single stale line.

## Resolution

| Cause | Fix |
|---|---|
| Address conflict | Fix DHCP/static assignment collision (see [topology IP plan](../01-architecture/network-topology.md#3-ip-addressing-plan)) |
| Missing firewall rule | Re-add with the scoped source only |
| Service stopped | Restart after `sshd -t` passes; fix the config error that stopped it |
| Key not authorized | Install the admin's public key into `~/.ssh/authorized_keys` (600 perms) |
| Account issue | `passwd -S <user>` / check account not disabled |

## Root-Cause Prevention

- Any sshd change follows the snapshot discipline: `pre-change` snapshot → edit → `sshd -t` → restart → `post-change` snapshot (Pillar 5).
- Firewall rules are managed only through the hardening script — no hand-edits that drift from [linux-baseline.md](../03-hardening-baselines/linux-baseline.md).
- RDP and SSH remain scoped to the management subnet — a "works from anywhere" tweak is how remote-access incidents start.

## Escalation to Tier-2

- Host-key change without a known rebuild → treat as security incident (potential MITM) — do not reconnect until verified.
- sshd repeatedly stopping (`journalctl` shows crash loop) → package/config integrity check before retrying.

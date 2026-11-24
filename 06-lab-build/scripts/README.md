# Hardening & Backup Scripts

Reproducible automation for the lab baseline. Every script is idempotent-safe (re-running applies the same state) except `backup-restore.sh`, which is append-only.

| Script | Node | Purpose | Run command |
|---|---|---|---|
| `linux/linux-hardening.sh` | SRV-LIN01 | Applies [Linux baseline](../../03-hardening-baselines/linux-baseline.md) rows 1–7: SSH key-only + no root, UFW default-deny scoped to mgmt subnet, unattended-upgrades, fail2ban, file permissions; prints verification summary | `sudo bash linux-hardening.sh` |
| `linux/backup-restore.sh` | SRV-LIN01 | 3-2-1 backups of `/srv/company-data` to `/srv/backups` — daily hardlink-deduplicated incremental, weekly full, checksum-verified restore | `sudo bash backup-restore.sh daily` · `weekly` · `restore <snapshot> <path>` · `list` |
| `windows/windows-hardening.ps1` | WIN-FIN01 | Applies [Windows baseline](../../03-hardening-baselines/windows-baseline.md) rows 1, 3–11: Defender, firewall profiles + scoped rules, SMBv1 off, guest off, AutoRun off, UAC verified, password/lockout policy, screen lock; prints BitLocker status | Elevated PowerShell: `powershell -ExecutionPolicy Bypass -File .\windows-hardening.ps1` |

**Notes**

- Run the hardening scripts once per node during the build (see [lab-build-guide.md](../lab-build-guide.md)); safe to re-run for drift correction.
- Cron entries for the backup schedule are set in [lab-build-guide.md §9](../lab-build-guide.md#9-backups-on-srv-lin01).
- The scripts print a verification summary at the end — compare it against the baseline compliance tables before marking rows green.

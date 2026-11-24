# Runbook C — "Workstation Running Extremely Slow / High Disk or CPU"

> **Version:** v1.0 · **Date:** 2026-11-24 · **Owner:** IT Support · **Tier:** 1
> **Typical call:** "My laptop is so slow it freezes."

## Symptom

Machine takes minutes to log in, applications hang, disk or CPU pinned at ~100% for extended periods.

## Tier-1 Triage Order

Diagnose the bottleneck resource first — slow machines have exactly one dominant cause most of the time.

| Step | Command / tool | What to look for | Interpretation |
|---|---|---|---|
| 1 | Task Manager → Processes (sort by CPU, then Memory, then Disk) | Top resource consumer by name | Runaway process = suspect; check its publisher/path |
| 2 | Task Manager → Startup apps | Enable count + impact | Startup bloat → disable high-impact non-essential entries |
| 3 | Resource Monitor (`resmon`) → Disk tab | Disk queue length, response time | Queue sustained > 2 with failing disk health = storage problem |
| 4 | Task Manager → Performance → check for malware signs | Unknown processes, Defender disabled, high network from unknown apps | Suspicious → stop troubleshooting, go to [Runbook D](runbook-d-malware.md) |
| 5 | Windows Update history | Pending updates / old build | Patch backlog → schedule update window |
| 6 | Disk free space | < 10% free on C: | Purge temp/old files, empty recycle bin |

Linux equivalents: `top` (CPU/mem leaders), `iostat -x 1` (disk utilization, await), `free -h` (memory pressure), `systemctl --user list-units --state=running`.

## Resolution

| Cause | Fix |
|---|---|
| Specific runaway app | Restart app; if it recurs, reinstall or remove |
| Startup bloat | Disable non-essential startup entries (standard image review) |
| Failing disk | Back up user data immediately (see Pillar 5), replace disk |
| Malware indicators | Switch to [Runbook D](runbook-d-malware.md) — containment before diagnosis |
| Memory saturation | Identify memory hog; upgrade RAM if workload legitimately exceeds 8 GB |

## Root-Cause Prevention

- Standard software image per department — no ad-hoc installs (UAC baseline enforces this on the endpoint).
- Quarterly startup-app review on all machines.
- Defender quick-scan scheduled daily; keeps row-4 surprises rare.
- Disk health in the annual asset review (`Get-PhysicalDisk` health status).

## Escalation to Tier-2

- Disk SMART warnings or physical faults → hardware replacement workflow, data preserved from backup first.
- Slowness on **many** machines simultaneously → environmental (update storm, network service, malware campaign) — correlate before per-machine fixes.

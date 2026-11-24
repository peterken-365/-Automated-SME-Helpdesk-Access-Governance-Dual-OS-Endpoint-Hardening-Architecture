# Runbook A — "No Internet / Cannot Reach Internal Portal"

> **Version:** v1.0 · **Date:** 2026-11-24 · **Owner:** IT Support · **Tier:** 1
> **Typical call:** "My internet is down" or "I can't open the company portal."

## Symptom

User reports no internet, no portal access, or "the network is off." The symptom says nothing about the layer — the ladder below isolates it bottom-up (OSI: Physical → Link → IP → Gateway → DNS).

## Tier-1 Isolation Ladder

Work strictly top-down. The first step that FAILS marks the layer; the first step that PASSES proves everything below it is fine.

| Step | Layer | Command (Windows) | Pass looks like | Fail means |
|---|---|---|---|---|
| 1 | Physical/Link | Check adapter state: `Get-NetAdapter` (or `ipconfig` — look for "Media disconnected") | Adapter `Up`, link present | Cable/Wi-Fi problem — check cable, Wi-Fi switch, AP |
| 2 | IP/DHCP | `ipconfig /all` | Valid address on the expected subnet | `169.254.x.x` = DHCP failure → `ipconfig /release` then `ipconfig /renew` |
| 3 | Gateway | `ping <gateway>` (lab example: `ping 192.168.56.1`) | Replies | Local segment or router problem — do NOT proceed to DNS testing |
| 4 | Beyond gateway | `ping 8.8.8.8` | Replies | Router/ISP issue, not the workstation |
| 5 | DNS | `nslookup <known-name>` (e.g., `nslookup google.com`) | Resolves | **If step 4 passed but step 5 fails: DNS-layer failure** — check DNS server setting (`ipconfig /all`), try `nslookup google.com 8.8.8.8` to compare servers |

Linux equivalents: `ip a` (state + address), `resolvectl status` (DNS config), `ping`, `dig @8.8.8.8 <name>`.

## Resolution

| Isolated layer | Fix |
|---|---|
| Physical | Re-seat cable / reconnect Wi-Fi; replace faulty cable |
| DHCP | Renew lease; if persistent, verify DHCP pool (production: 192.168.56.100–200) not exhausted |
| Gateway | Reboot router if authorized; log ticket with ISP if external |
| DNS | Switch to secondary DNS; flush cache: `ipconfig /flushdns` |

## Root-Cause Prevention

- Monitor DHCP pool utilization; expand scope before exhaustion.
- Configure a secondary DNS server so single-server outages aren't user-visible.
- Record the isolated layer for every ticket — recurring same-layer failures justify infrastructure spend.

## Escalation to Tier-2

- Steps 1–2 pass but the user still can't work, and steps 3–4 fail on **multiple machines** → infrastructure outage, not endpoint: escalate with the isolated layer stated.
- Suspected malware interfering with networking (proxy settings changed, unknown adapters) → follow [Runbook D](runbook-d-malware.md) first.

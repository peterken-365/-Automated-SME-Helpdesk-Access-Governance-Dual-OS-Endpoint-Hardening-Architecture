# Virtual Machine Inventory & Hardware Allocation

> **Version:** v1.0 · **Date:** 2026-11-24 · **Owner:** IT Support · **Scope:** Savannah Logistics Ltd. lab

## 1. Host Platform

| Attribute | Value |
|---|---|
| Physical host / control node | LAP-IT01 (Lenovo ThinkPad) |
| CPU | Intel Core i5-7300U @ 2.60 GHz (2 cores / 4 threads) |
| RAM | 7.8 GB usable |
| Storage | ~120 GB free on host SSD |
| Hypervisor | Oracle VirtualBox 7.x (free) |
| Host OS | Windows 10 |

## 2. VM Hardware Allocation

Allocation is sized to the 7.8 GB host budget: both VMs run concurrently with headroom left for the host OS.

| Node | OS | vCPU | RAM | Disk (dynamic VDI) | Role |
|---|---|---|---|---|---|
| WIN-FIN01 | Windows 10 (unactivated evaluation — fully functional) | 2 | 4096 MB | 50 GB | Finance/HR endpoint; standard-user boundary, ACL shares, host firewall |
| SRV-LIN01 | Ubuntu Server 24.04 LTS | 1 | 1536 MB | 20 GB | Linux server; key-based SSH, UFW default-deny, rsync backup target |

Concurrent footprint: 5.6 GB of the 7.8 GB host RAM — the maximum this platform supports, which drives the design decision below.

## 3. Design Decision: Host as Admin/Control Node

The reference blueprint calls for a third VM (an admin/helpdesk control node). This lab consolidates that role onto the **physical host itself** (LAP-IT01, 192.168.56.1):

- **Constraint:** 7.8 GB host RAM cannot run three VMs concurrently without thrashing.
- **Architectural justification:** the helpdesk workstation is the physical machine the support engineer sits at. VirtualBox's host-only networking puts the host on the management subnet by design, so the host reaches both endpoints for diagnostics, port scans, and backup verification with no additional VM.
- **Documented trade-off:** admin tooling lives on the host OS rather than an isolated VM. In a production deployment the control node would be a hardened management workstation or jump host on the management VLAN.

## 4. Software Inventory

| Component | Version | Node | Purpose |
|---|---|---|---|
| Oracle VirtualBox | 7.x | LAP-IT01 | Hypervisor for both VMs |
| Windows 10 | 22H2 eval | WIN-FIN01 | Endpoint OS |
| Ubuntu Server | 24.04 LTS | SRV-LIN01 | Server OS |
| OpenSSH server | distro default | SRV-LIN01 | Key-based remote administration |
| UFW + fail2ban | distro default | SRV-LIN01 | Default-deny firewall + brute-force lockout |
| unattended-upgrades | distro default | SRV-LIN01 | Automatic security patches |
| rsync | distro default | SRV-LIN01 | 3-2-1 backup snapshots |
| Windows Defender + Firewall | OS built-in | WIN-FIN01 | Malware protection + host firewall |
| Hardening scripts | v1.0 | both | `06-lab-build/scripts/` — reproducible baseline |

## 5. Snapshot & Change Policy

VirtualBox snapshots back the change-control process (Pillar 5):

- A snapshot named `pre-change-<description>` is taken before any OS or firewall change.
- The change is applied, then validated against the relevant baseline checklist.
- A `post-change-<description>` snapshot marks the known-good state.
- The baseline snapshot after initial hardening is named `post-hardening-baseline`.

Procedure detail: [lab-build-guide.md §8](../06-lab-build/lab-build-guide.md#8-run-hardening--snapshot).

## 6. Remote Access Matrix

| Node | Access method | Who | Scope |
|---|---|---|---|
| WIN-FIN01 | RDP (3389) | IT Support from LAP-IT01 | 192.168.56.0/24 only |
| SRV-LIN01 | SSH (22, key-only) | IT Support from LAP-IT01 | 192.168.56.0/24 only, password auth disabled |

Console access remains available through the VirtualBox window for break-glass recovery.

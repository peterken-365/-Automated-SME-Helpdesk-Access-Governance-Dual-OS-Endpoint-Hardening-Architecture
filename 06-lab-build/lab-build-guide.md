# Lab Build Guide — Rebuild the Entire Environment From Zero

> **Version:** v1.0 · **Date:** 2026-11-24 · **Owner:** IT Support
> This guide reproduces the full lab (architecture, identity, hardening, backups, evidence) on any 2-core / 8 GB machine using **only free software**. Follow the sections in order.

---

## 0. What You Need

| Requirement | Value |
|---|---|
| Hardware floor | 2-core CPU with virtualization (VT-x/AMD-V), 8 GB RAM, 40 GB free disk |
| Hypervisor | Oracle VirtualBox 7.x — https://www.virtualbox.org/wiki/Downloads |
| Windows 10 ISO | https://www.microsoft.com/en-us/software-download/windows10 (official; unactivated installs are fully functional — activation is optional and costs nothing extra to skip in the lab) |
| Ubuntu Server 24.04 ISO | https://ubuntu.com/download/server |
| The scripts in this repo | `06-lab-build/scripts/` |

**Time budget:** ~3–4 hours total (ISO downloads and OS installs dominate).

---

## 1. Install VirtualBox + Verify Networking

1. Install VirtualBox with default options.
2. Open **File → Tools → Network Manager → Host-only Networks**: the `VirtualBox Host-Only Ethernet Adapter` must exist with IPv4 `192.168.56.1`, mask `255.255.255.0`, **DHCP Server tab: disabled** (we assign statically).
3. This adapter makes the physical host node **LAP-IT01** on the management subnet (see [architecture](../01-architecture/network-topology.md)).

---

## 2. Create WIN-FIN01 (Windows 10 Endpoint)

1. **New VM:** Name `WIN-FIN01` · Type Microsoft Windows · Version Windows 10 (64-bit).
2. **System:** 4096 MB RAM, 2 CPUs; **Storage:** 50 GB VDI, dynamic allocation; mount the Win10 ISO.
3. Install Windows → **skip the product key** → choose "Windows 10 Pro" → custom install to the VM disk.
4. During OOBE, create local account `itsupport` (temporary setup admin; department users come in §6). Use offline/local-account options where offered.
5. After first login: **Devices menu → Insert Guest Additions CD**, run the installer (better resolution + shared clipboard for evidence screenshots), reboot.
6. Rename the computer to `WIN-FIN01` (Settings → System → About → Rename) and reboot.

---

## 3. Create SRV-LIN01 (Ubuntu Server 24.04)

1. **New VM:** Name `SRV-LIN01` · Type Linux · Ubuntu (64-bit). 1536 MB RAM, 1 CPU, 20 GB dynamic VDI; mount the Ubuntu ISO.
2. Installer: hostname `SRV-LIN01`, user `itsupport` (strong password — it is the sudo account), **check "Install OpenSSH server"**. Skip snaps.
3. Reboot, log in via VirtualBox console once to confirm.

### 3a. Automated alternative — one-command Linux node (Vagrant)

Skip manual creation of SRV-LIN01 entirely. With VirtualBox + Vagrant installed:

```bash
cd 06-lab-build
vagrant up
```

This builds the VM (bento/ubuntu-24.04, 1536 MB / 1 vCPU, host-only **192.168.56.20**) and applies `scripts/linux/linux-hardening.sh` as the provisioner — the same script, unmodified, that §8 runs by hand. It also adds one lab-only rule keeping Vagrant's NAT control plane reachable after UFW default-deny (commented in the [Vagrantfile](Vagrantfile); not part of the production-pattern node). First run downloads the box image (~500 MB).

Continue with §5 name resolution, §6 identity setup, and §9 backups on this node as documented. WIN-FIN01 remains click-by-click (§2) — automating a Windows VM requires licensed media, which this project deliberately avoids.

---

## 4. Dual-Interface Networking

Both VMs, in VirtualBox **Settings → Network**:

| Adapter | Attached to | Purpose |
|---|---|---|
| Adapter 1 | NAT | Updates / internet (outbound only) |
| Adapter 2 | Host-only Adapter (192.168.56.1) | Management subnet |

**Windows static IP (WIN-FIN01):** Settings → Network & Internet → change adapter options → the host-only adapter (usually "Ethernet 2") → IPv4 Properties: `192.168.56.10` / mask `255.255.255.0` / **leave gateway empty** (management path must not route outward).

**Ubuntu static IP (SRV-LIN01):** create `/etc/netplan/01-mgmt.yaml`:

```yaml
network:
  version: 2
  ethernets:
    enp0s8:
      addresses: [192.168.56.20/24]
      # no gateway: management path stays isolated
      dhcp4: false
```

Apply: `sudo netplan apply`. Identify the host-only interface with `ip a` (the one whose NAT sibling is `enp0s3`; adjust name if different).

**Verify from the host (LAP-IT01):** `ping 192.168.56.10` and `ping 192.168.56.20` must both reply.

---

## 5. Hosts-File Name Resolution

Add these identical entries on **all three** nodes (host: `C:\Windows\System32\drivers\etc\hosts` elevated; VMs: `/etc/hosts`):

```
192.168.56.1    LAP-IT01
192.168.56.10   WIN-FIN01
192.168.56.20   SRV-LIN01
```

Verify: `ping WIN-FIN01` and `ping SRV-LIN01` resolve correctly.

---

## 6. Identity Setup

**Windows (elevated Command Prompt on WIN-FIN01):**

```bat
:: department users (standard accounts)
net user awanjiru <strong-password> /add
:: dedicated admin account for the same person
net user awanjiru-adm <strong-password> /add
net localgroup Administrators awanjiru-adm /add

:: department groups per RBAC matrix
net localgroup GRP-Finance /add
net localgroup GRP-Operations /add
net localgroup GRP-ITSUPPORT /add
net localgroup GRP-Interns /add

:: membership
net localgroup GRP-Finance awanjiru /add
net localgroup Users awanjiru /add
net localgroup GRP-ITSUPPORT itsupport /add
```

`awanjiru` is created as a plain standard user (no elevation) — the `username-adm` account holds the admin rights ([JML policy](../02-identity-and-access/jml-policy.md)).

**Ubuntu (on LAP-IT01, then SRV-LIN01):** generate a dedicated admin key and install it for `itsupport`:

```bash
# on LAP-IT01
ssh-keygen -t ed25519 -f ~/.ssh/srv-lin01-ed25519 -C "it-support-SRV-LIN01"
ssh itsupport@192.168.56.20 "mkdir -p ~/.ssh && chmod 700 ~/.ssh"   # last password use
type C:\Users\<you>\.ssh\srv-lin01-ed25519.pub | ssh itsupport@192.168.56.20 "cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
ssh -i ~/.ssh/srv-lin01-ed25519 itsupport@192.168.56.20   # key login must work BEFORE hardening
```

Confirm `itsupport` is in the `sudo` group: `getent group sudo`.

---

## 7. RBAC Folders + ACLs

On WIN-FIN01 (elevated): create and share the three resources, then apply the exact ACLs from the [RBAC matrix](../02-identity-and-access/rbac-matrix.md):

```bat
mkdir C:\Corp\Finance-Shared C:\Corp\Company-Templates C:\Corp\IT-Admin-Logs

net share Finance-Shared=C:\Corp\Finance-Shared /grant:Everyone,READ
net share Company-Templates=C:\Corp\Company-Templates /grant:Everyone,READ
net share IT-Admin-Logs=C:\Corp\IT-Admin-Logs /grant:Everyone,READ

icacls "C:\Corp\Finance-Shared" /inheritance:r /grant:r "GRP-Finance:(OI)(CI)M" /grant:r "GRP-ITSUPPORT:(OI)(CI)RX" /grant:r "SYSTEM:(OI)(CI)F" /grant:r "Administrators:(OI)(CI)F"
icacls "C:\Corp\Company-Templates" /inheritance:r /grant:r "GRP-Finance:(OI)(CI)RX" /grant:r "GRP-Operations:(OI)(CI)RX" /grant:r "GRP-ITSUPPORT:(OI)(CI)M" /grant:r "GRP-Interns:(OI)(CI)RX" /grant:r "SYSTEM:(OI)(CI)F" /grant:r "Administrators:(OI)(CI)F"
icacls "C:\Corp\IT-Admin-Logs" /inheritance:r /grant:r "GRP-ITSUPPORT:(OI)(CI)F" /grant:r "SYSTEM:(OI)(CI)F" /grant:r "Administrators:(OI)(CI)F"
```

Seed demo content: an `expense-template.xlsx` in Company-Templates, a sample `sample-audit.log` in IT-Admin-Logs, a `reports\` subfolder with `quarterly-summary.odt` in Finance-Shared.

Enable RDP for IT support: Settings → System → Remote Desktop → On (the firewall rule scoping it to the mgmt subnet comes in §8).

---

## 8. Run Hardening + Snapshot

**Windows (elevated PowerShell on WIN-FIN01):**

```powershell
powershell -ExecutionPolicy Bypass -File .\windows-hardening.ps1
```

**Linux (on SRV-LIN01, after copying the script over):**

```bash
sudo bash linux-hardening.sh
```

Compare both outputs against the [Windows](../03-hardening-baselines/windows-baseline.md) and [Linux](../03-hardening-baselines/linux-baseline.md) baseline tables.

**Change control (Pillar 5):** once both baselines verify green, take a VirtualBox snapshot of each VM named `post-hardening-baseline`. Every later OS/firewall change gets `pre-change-*` / `post-change-*` snapshots around it.

---

## 9. Backups on SRV-LIN01

```bash
sudo mkdir -p /srv/company-data/reports /opt/scripts
sudo cp <backup-restore.sh location> /opt/scripts/backup-restore.sh
echo "quarterly logistics summary - demo content" | sudo tee /srv/company-data/reports/quarterly-summary.odt
sudo bash /opt/scripts/backup-restore.sh daily        # first snapshot
```

Schedule (crontab -e as root):

```cron
# daily incremental 18:00, weekly full Sunday 02:00
0 18 * * * /usr/bin/env bash /opt/scripts/backup-restore.sh daily
0 2 * * 0 /usr/bin/env bash /opt/scripts/backup-restore.sh weekly
```

---

## 10. Baseline Verification Pass

Run every command in the two baseline tables' "Verification" column ([Windows](../03-hardening-baselines/windows-baseline.md) · [Linux](../03-hardening-baselines/linux-baseline.md)). Every row must match the required setting before running the test matrix below.

---

## 11. Run the Validation Tests (T-01 … T-06)

Execute exactly as scripted in [test_results.md](../05-validation-evidence/test_results.md) (each test's procedure is written out there with commands). Capture evidence as you go:

| Test | Action | Screenshot filename |
|---|---|---|
| T-01 | As `awanjiru`: attempt install + firewall change | `T-01-uac-elevation-prompt.png` |
| T-02 | Password + root SSH attempts from LAP-IT01; auth.log on server | `T-02-ssh-password-rejected.png`, `T-02-auth-log-lockout.png` |
| T-03 | PowerShell port sweep from LAP-IT01 | `T-03-win-port-status.png`, `T-03-linux-port-status.png` |
| T-04 | As `awanjiru`: open IT-Admin-Logs share | `T-04-acl-access-denied.png` |
| T-05 | Break DNS → Runbook A ladder → revert | `T-05-dns-ip-ok-name-fail.png` |
| T-06 | Delete + restore `quarterly-summary.odt`, checksum | `T-06-file-deleted.png`, `T-06-file-restored.png` |

**Screenshot capture:** Windows VM — `Win+Shift+S` (Snipping Tool); Linux — screenshot the SSH terminal window on LAP-IT01. Save directly into `05-validation-evidence/images/` with the exact filenames above.

**Privacy:** the VMs are isolated from your real machine, but keep the evidence clean — no real names, emails, or personal directories in frame.

---

## 12. Update the Evidence

For each executed test, tick the physical capture checklist and set the **Physical lab (Tier 3)** cell to ✅ with the capture date in [test_results.md](../05-validation-evidence/test_results.md), drop the screenshots into `images/` with the exact filenames, confirm the image embeds resolve, and flip the corresponding **Physical lab** cell in the [README verification table](../README.md#5-verification--testing-matrix) to ✅. A backup or control that was never tested is treated as not existing.

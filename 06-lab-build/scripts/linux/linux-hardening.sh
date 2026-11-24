#!/usr/bin/env bash
# linux-hardening.sh — SRV-LIN01 security baseline (Ubuntu Server 24.04 LTS)
# Implements 03-hardening-baselines/linux-baseline.md rows 1-7.
# Run as root:  sudo bash linux-hardening.sh
set -euo pipefail

MGMT_SUBNET="192.168.56.0/24"

echo "=== [1/6] SSH: key-only auth, no root login ==="
SSHD=/etc/ssh/sshd_config
cp "$SSHD" "${SSHD}.bak.$(date +%F)"
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD"
sed -i 's/^#\?KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' "$SSHD"
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' "$SSHD"
grep -q '^PubkeyAuthentication yes' "$SSHD" || echo 'PubkeyAuthentication yes' >> "$SSHD"
sshd -t
systemctl restart ssh

echo "=== [2/6] Host firewall: UFW default-deny, scoped SSH ==="
apt-get install -y ufw
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow from "$MGMT_SUBNET" to any port 22 proto tcp comment 'SSH from mgmt subnet'
ufw --force enable

echo "=== [3/6] Automated unattended security updates ==="
apt-get install -y unattended-upgrades
printf 'APT::Periodic::Update-Package-Lists "1";\nAPT::Periodic::Unattended-Upgrade "1";\n' > /etc/apt/apt.conf.d/20auto-upgrades
systemctl enable --now unattended-upgrades

echo "=== [4/6] Brute-force lockout: fail2ban sshd jail ==="
apt-get install -y fail2ban
cat > /etc/fail2ban/jail.local <<'EOF'
[sshd]
enabled = true
maxretry = 5
bantime = 30m
findtime = 10m
EOF
systemctl enable --now fail2ban

echo "=== [5/6] Least-privilege file permissions ==="
chmod 600 /etc/ssh/sshd_config
chmod 700 /root
for d in /home/*; do chmod 750 "$d"; done

echo "=== [6/6] Verification summary ==="
echo "--- sshd effective settings ---"
sshd -T | grep -E 'permitrootlogin|passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication'
echo "--- ufw ---"
ufw status verbose
echo "--- fail2ban sshd jail ---"
fail2ban-client status sshd || true
echo "--- permissions ---"
stat -c '%a %n' /etc/ssh/sshd_config /root /home/*
echo "Hardening complete. Compare output above against 03-hardening-baselines/linux-baseline.md."

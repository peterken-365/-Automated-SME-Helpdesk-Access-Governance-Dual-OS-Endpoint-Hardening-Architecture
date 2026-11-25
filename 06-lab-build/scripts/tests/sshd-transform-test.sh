#!/usr/bin/env bash
# sshd-transform-test.sh — unit test for linux-hardening.sh's sshd_config edit logic.
#
# Validates the exact transformation block from linux-hardening.sh against a
# representative stock Ubuntu 24.04 /etc/ssh/sshd_config fixture:
#   1. Commented defaults become hard-disabled directives.
#   2. PubkeyAuthentication yes is appended when absent.
#   3. Exactly one uncommented occurrence of each directive remains (idempotent
#      under re-run — a second hardening pass must not duplicate lines).
#
# CI-safe: operates on a temp fixture only, never touches the real sshd config.
# The transformation lines are extracted live from linux-hardening.sh, so the
# test can never drift from the script it validates.
#
# Usage: bash sshd-transform-test.sh [path-to-linux-hardening.sh]
set -euo pipefail

HARDEN="${1:-$(cd "$(dirname "$0")" && pwd)/../linux/linux-hardening.sh}"
[ -f "$HARDEN" ] || { echo "FAIL: hardening script not found: $HARDEN"; exit 1; }

FIXDIR=$(mktemp -d)
trap 'rm -rf "$FIXDIR"' EXIT
SSHD="$FIXDIR/sshd_config"

# Representative stock Ubuntu 24.04 /etc/ssh/sshd_config (relevant directives)
cat > "$SSHD" <<'EOF'
Include /etc/ssh/sshd_config.d/*.conf

#PubkeyAuthentication yes

# The strategy used for options in the default sshd_config are:
#Comment the option to change.

#PasswordAuthentication yes
#PermitRootLogin prohibit-password
#KbdInteractiveAuthentication yes
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

run_transform() {
  # Execute every line of linux-hardening.sh that operates on "$SSHD"
  # (backup copy, the three hard-disable seds, the Pubkey append, chmod 600).
  while IFS= read -r line; do eval "$line"; done < <(grep -F '"$SSHD"' "$HARDEN")
}

echo "=== sshd_config transform unit test (source of truth: $HARDEN) ==="
echo
echo "--- lines under test (extracted live from the script) ---"
grep -F '"$SSHD"' "$HARDEN"
echo

run_transform

echo "--- transformed fixture: relevant directives ---"
grep -nE '^(PasswordAuthentication|KbdInteractiveAuthentication|PermitRootLogin|PubkeyAuthentication)' "$SSHD"
echo

fail=0
assert_count() { # <directive> <expected-count> <description>
  local n
  n=$(grep -cE "^$1 " "$SSHD" || true)
  if [ "$n" -eq "$2" ]; then
    echo "PASS: $3 (found $n)"
  else
    echo "FAIL: $3 (expected $2, found $n)"
    fail=1
  fi
}

assert_count PasswordAuthentication 1 "PasswordAuthentication hard-disabled exactly once"
assert_count KbdInteractiveAuthentication 1 "KbdInteractiveAuthentication hard-disabled exactly once"
assert_count PermitRootLogin 1 "PermitRootLogin hard-disabled exactly once"
assert_count PubkeyAuthentication 1 "PubkeyAuthentication enabled exactly once (appended)"

if grep -qE '^#(PasswordAuthentication|KbdInteractiveAuthentication|PermitRootLogin) ' "$SSHD"; then
  echo "FAIL: commented defaults still present — sed left stale commented directives"
  fail=1
else
  echo "PASS: commented defaults fully rewritten (no stale directives)"
fi

if grep -qE '^(PasswordAuthentication|KbdInteractiveAuthentication|PermitRootLogin) (yes|prohibit-password)' "$SSHD"; then
  echo "FAIL: a directive retained an insecure value"
  fail=1
else
  echo "PASS: no directive retains an insecure value"
fi

# Idempotency: a second hardening pass must not duplicate directives.
run_transform
echo
echo "--- idempotency: after a second transform pass ---"
assert_count PasswordAuthentication 1 "re-run: still exactly one PasswordAuthentication line"
assert_count PermitRootLogin 1 "re-run: still exactly one PermitRootLogin line"
assert_count PubkeyAuthentication 1 "re-run: still exactly one PubkeyAuthentication line"

echo
if [ "$fail" -eq 0 ]; then
  echo "RESULT: ALL CHECKS PASSED — sshd_config transform logic matches 03-hardening-baselines/linux-baseline.md rows 1-2"
else
  echo "RESULT: FAILURES DETECTED"
fi
exit "$fail"

#!/usr/bin/env bash
# smoke.sh - drive bin/battery-alert against a fake /sys/class/power_supply.
#
# Notifications are printed instead of sent (DRY_RUN=1) and sounds are muted,
# so the test is safe to run on a machine that is actually on battery power.
# Takes about 12 seconds because the watcher is driven by real polling.

set -uo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
pid=""

cleanup() {
    [[ -n $pid ]] && kill "$pid" 2>/dev/null
    rm -rf "$tmp"
}
trap cleanup EXIT

sys="$tmp/sys"
mkdir -p "$sys/BAT0" "$sys/AC"
echo Battery >"$sys/BAT0/type"
echo Mains >"$sys/AC/type"
echo Discharging >"$sys/BAT0/status"
echo 20000000 >"$sys/BAT0/energy_now"
echo 20000000 >"$sys/BAT0/power_now"
echo 25 >"$sys/BAT0/capacity"
echo 0 >"$sys/AC/online"

log="$tmp/log"
SYSFS="$sys" DRY_RUN=1 SOUND=0 POLL=1 REPEAT=2 \
    "$repo/bin/battery-alert" >"$log" 2>&1 &
pid=$!

# one step per charge level, long enough for at least one poll to see it
step() { echo "$1" >"$sys/BAT0/capacity"; sleep 1.7; }

fail=0
expect() {
    if grep -q -- "$1" "$log"; then
        printf 'ok   %s\n' "$1"
    else
        printf 'FAIL %s\n' "$1"
        fail=1
    fi
}

step 19
expect 'stage 20% announced'
step 9
expect 'stage 10% announced'
step 4
expect 'stage 5% announced'
sleep 2.2
expect 'stage 5% repeated'
step 1
expect 'stage 2% announced'
echo 1 >"$sys/AC/online"
sleep 1.7
expect 'clearing warnings'

kill "$pid" 2>/dev/null
pid=""

if (( fail )); then
    printf '\n--- watcher output ---\n'
    cat "$log"
    exit 1
fi

printf '\nall checks passed\n'

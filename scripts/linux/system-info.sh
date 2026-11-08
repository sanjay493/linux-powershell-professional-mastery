#!/usr/bin/env bash
#
# system-info.sh — Read-only system identity and inventory report for Linux.
#
# Course : Linux & PowerShell Professional Mastery (Day 01)
# Target : Ubuntu 24.04 LTS (works on most systemd-based distributions)
# Needs  : bash 4+, coreutils, procps (free), iproute2 (ip). No root required.
#
# Usage  : ./system-info.sh [-o OUTPUT_DIR] [-f text|csv] [-h]
#   -o DIR   Also save the report to DIR/system-info-<host>-<UTC timestamp>.<ext>
#   -f FMT   Output format: text (default) or csv (key,value pairs)
#   -h       Show help
#
# Exit codes: 0 success · 1 invalid arguments · 2 output directory problem
#
# Safety: this script only READS information. It changes nothing on the system.

set -o nounset
set -o pipefail

readonly SCRIPT_NAME="${0##*/}"
FORMAT="text"
OUTPUT_DIR=""

usage() {
    sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
}

die() {
    printf '%s: error: %s\n' "$SCRIPT_NAME" "$1" >&2
    exit "${2:-1}"
}

# Run a command, returning "n/a" instead of failing when the tool is missing or errors.
safe() {
    local out
    if out="$("$@" 2>/dev/null)" && [[ -n "$out" ]]; then
        printf '%s' "$out"
    else
        printf 'n/a'
    fi
}

have() { command -v "$1" >/dev/null 2>&1; }

# ---------- argument parsing ----------
while getopts ":o:f:h" opt; do
    case "$opt" in
        o) OUTPUT_DIR="$OPTARG" ;;
        f) FORMAT="$OPTARG" ;;
        h) usage; exit 0 ;;
        :) die "option -$OPTARG requires an argument" ;;
        \?) die "unknown option -$OPTARG (use -h for help)" ;;
    esac
done

case "$FORMAT" in
    text|csv) ;;
    *) die "invalid format '$FORMAT' (expected text or csv)" ;;
esac

if [[ -n "$OUTPUT_DIR" ]]; then
    mkdir -p -- "$OUTPUT_DIR" 2>/dev/null || die "cannot create output directory '$OUTPUT_DIR'" 2
    [[ -w "$OUTPUT_DIR" ]] || die "output directory '$OUTPUT_DIR' is not writable" 2
fi

# ---------- data collection ----------
os_name="n/a"
if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    os_name="$(. /etc/os-release && printf '%s' "${PRETTY_NAME:-${NAME:-n/a}}")"
fi

cpu_model="n/a"
if [[ -r /proc/cpuinfo ]]; then
    cpu_model="$(awk -F': ' '/^model name/ {print $2; exit}' /proc/cpuinfo | sed 's/[[:space:]]*$//')"
    [[ -z "$cpu_model" ]] && cpu_model="n/a"
fi

cpu_cores="$(safe nproc)"
load_avg="n/a"
[[ -r /proc/loadavg ]] && load_avg="$(cut -d' ' -f1-3 /proc/loadavg)"

mem_total="n/a"; mem_used="n/a"; mem_avail="n/a"
if have free; then
    # free -m columns: total used free shared buff/cache available
    read -r mem_total mem_used mem_avail < <(free -m | awk '/^Mem:/ {print $2"MiB", $3"MiB", $7"MiB"}')
fi

root_disk="n/a"
if have df; then
    root_disk="$(df -h --output=size,used,avail,pcent / 2>/dev/null | awk 'NR==2 {print $2" used of "$1" ("$4"), "$3" free"}')"
    [[ -z "$root_disk" ]] && root_disk="n/a"
fi

ip_addrs="n/a"; gateway="n/a"
if have ip; then
    ip_addrs="$(ip -4 -o addr show scope global 2>/dev/null | awk '{print $2"="$4}' | paste -sd ' ' -)"
    [[ -z "$ip_addrs" ]] && ip_addrs="n/a"
    gateway="$(ip route show default 2>/dev/null | awk '/default/ {print $3" via "$5; exit}')"
    [[ -z "$gateway" ]] && gateway="n/a"
fi

dns_servers="n/a"
if [[ -r /etc/resolv.conf ]]; then
    dns_servers="$(awk '/^nameserver/ {print $2}' /etc/resolv.conf | paste -sd ' ' -)"
    [[ -z "$dns_servers" ]] && dns_servers="n/a"
fi

uptime_pretty="$(safe uptime -p)"
boot_time="$(safe uptime -s)"
timestamp_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
host_name="$(safe hostname)"

# Ordered key/value pairs keep text and CSV output consistent.
keys=(
    "Report time (UTC)" "Host name" "Current user" "Operating system" "Kernel release"
    "Architecture" "CPU model" "CPU cores" "Load average (1/5/15)" "Memory total"
    "Memory used" "Memory available" "Root filesystem" "IPv4 addresses" "Default gateway"
    "DNS servers" "Uptime" "Boot time" "Shell"
)
values=(
    "$timestamp_utc" "$host_name" "$(safe whoami)" "$os_name" "$(safe uname -r)"
    "$(safe uname -m)" "$cpu_model" "$cpu_cores" "$load_avg" "$mem_total"
    "$mem_used" "$mem_avail" "$root_disk" "$ip_addrs" "$gateway"
    "$dns_servers" "$uptime_pretty" "$boot_time" "${BASH_VERSION:-n/a}"
)

# ---------- rendering ----------
render_text() {
    printf '==============================================\n'
    printf ' System Information Report\n'
    printf '==============================================\n'
    local i
    for i in "${!keys[@]}"; do
        printf '%-24s : %s\n' "${keys[$i]}" "${values[$i]}"
    done
}

csv_escape() {
    local s="${1//\"/\"\"}"
    printf '"%s"' "$s"
}

render_csv() {
    printf 'Property,Value\n'
    local i
    for i in "${!keys[@]}"; do
        printf '%s,%s\n' "$(csv_escape "${keys[$i]}")" "$(csv_escape "${values[$i]}")"
    done
}

if [[ "$FORMAT" == "csv" ]]; then
    report="$(render_csv)"
    ext="csv"
else
    report="$(render_text)"
    ext="txt"
fi

printf '%s\n' "$report"

if [[ -n "$OUTPUT_DIR" ]]; then
    safe_host="${host_name//[^A-Za-z0-9._-]/_}"
    outfile="$OUTPUT_DIR/system-info-${safe_host}-$(date -u +%Y%m%dT%H%M%SZ).${ext}"
    printf '%s\n' "$report" > "$outfile" || die "failed to write '$outfile'" 2
    printf '\nReport saved to: %s\n' "$outfile" >&2
fi

exit 0

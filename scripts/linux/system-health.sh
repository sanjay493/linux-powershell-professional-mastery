#!/usr/bin/env bash
#
# system-health.sh — Read-only, thresholded health check designed to be scheduled (cron/timer).
#
# Course : Linux & PowerShell Professional Mastery (Day 25)
# Target : Ubuntu 24.04 LTS (works on any Linux with /proc, GNU coreutils and, optionally, systemd)
# Needs  : bash 4+, GNU coreutils (df --output, nproc, date), awk. No root required.
#          systemctl is used for -s and the failed-units check; both show n/a when systemd
#          is not running (containers, WSL without systemd).
#
# Usage  : ./system-health.sh [-c CPU_PCT] [-m MEM_PCT] [-d DISK_PCT] [-s UNIT[,UNIT...]]
#                             [-f text|csv] [-o OUTPUT_DIR] [-q] [-h]
#   -c CPU_PCT   Warn when the 1-minute load average per CPU, in percent, is at or above
#                CPU_PCT, 1-1000 (default 90; 100 = one runnable task per CPU)
#   -m MEM_PCT   Warn when memory used (MemTotal - MemAvailable) or swap used is at or
#                above MEM_PCT, 1-100 (default 90)
#   -d DISK_PCT  Warn when a real filesystem's space or inode use is at or above DISK_PCT,
#                1-100 (default 90)
#   -s UNITS     Comma-separated systemd units that must be active (e.g. ssh,cron)
#   -f FMT       Output format: text (default) or csv (Check,Item,Value,Threshold,Status)
#   -o DIR       Also save the report to DIR/system-health-<host>-<UTC timestamp>.<ext>
#                (the file is written on every run, also when -q prints nothing)
#   -q           Quiet: print nothing when the overall status is OK (for cron mail)
#   -h           Show this help
#
# Checks : CPU load, memory, swap, filesystem space and inodes, listed units, failed
#          systemd units, reboot required (/var/run/reboot-required), uptime.
#          Each check is OK, WARNING (threshold reached) or n/a (cannot be measured).
#
# Exit codes: 0 OK · 1 invalid arguments · 2 output directory problem
#             3 at least one check is WARNING
#
# Safety: this script only READS (/proc, df, systemctl is-active/--failed). It changes nothing.

set -o nounset
set -o pipefail

readonly SCRIPT_NAME="${0##*/}"
CPU_T=90
MEM_T=90
DISK_T=90
UNITS=""
FORMAT="text"
OUTPUT_DIR=""
QUIET=0

# Filesystem types that describe memory, packages or kernel interfaces, not disks
# (the same list as disk-monitor.sh).
readonly PSEUDO_TYPES="tmpfs devtmpfs squashfs overlay proc sysfs cgroup cgroup2 devpts \
mqueue debugfs tracefs securityfs pstore efivarfs bpf autofs fusectl configfs hugetlbfs \
ramfs nsfs binfmt_misc rpc_pipefs fuse.portal fuse.gvfsd-fuse fuse.snapfuse"

usage() {
    sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'
}

die() {
    printf '%s: error: %s\n' "$SCRIPT_NAME" "$1" >&2
    exit "${2:-1}"
}

is_int() { [[ "$1" =~ ^[0-9]+$ ]]; }
# in_range VALUE MIN MAX — true when VALUE is a whole number between MIN and MAX.
in_range() { is_int "$1" && (( 10#$1 >= $2 && 10#$1 <= $3 )); }

# ---------- argument parsing ----------
while getopts ":c:m:d:s:f:o:qh" opt; do
    case "$opt" in
        c) CPU_T="$OPTARG" ;;
        m) MEM_T="$OPTARG" ;;
        d) DISK_T="$OPTARG" ;;
        s) UNITS="$OPTARG" ;;
        f) FORMAT="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        q) QUIET=1 ;;
        h) usage; exit 0 ;;
        :) die "option -$OPTARG requires an argument" ;;
        \?) die "unknown option -$OPTARG (use -h for help)" ;;
    esac
done
shift $((OPTIND - 1))
[[ $# -eq 0 ]] || die "unexpected argument '$1' (use -h for help)"

if ! in_range "$CPU_T" 1 1000; then die "-c must be an integer from 1 to 1000"; fi
if ! in_range "$MEM_T" 1 100; then die "-m must be an integer from 1 to 100"; fi
if ! in_range "$DISK_T" 1 100; then die "-d must be an integer from 1 to 100"; fi
CPU_T=$((10#$CPU_T)); MEM_T=$((10#$MEM_T)); DISK_T=$((10#$DISK_T))
case "$FORMAT" in
    text|csv) ;;
    *) die "invalid format '$FORMAT' (expected text or csv)" ;;
esac

unit_list=()
if [[ -n "$UNITS" ]]; then
    IFS=',' read -r -a unit_list <<< "$UNITS"
    for u in "${unit_list[@]}"; do
        # systemd unit names: letters, digits and : _ . @ - (\ for escaped names).
        [[ "$u" =~ ^[A-Za-z0-9:_.@\\-]+$ ]] || die "invalid unit name '$u' in -s"
    done
fi

if [[ -n "$OUTPUT_DIR" ]]; then
    mkdir -p -- "$OUTPUT_DIR" 2>/dev/null || die "cannot create output directory '$OUTPUT_DIR'" 2
    [[ -w "$OUTPUT_DIR" ]] || die "output directory '$OUTPUT_DIR' is not writable" 2
fi

# ---------- helpers ----------
results=""            # one TAB-separated record per check: check item value threshold status
add() { results+="$1"$'\t'"$2"$'\t'"$3"$'\t'"$4"$'\t'"$5"$'\n'; }

# level VALUE THRESHOLD — prints WARNING when VALUE >= THRESHOLD, OK otherwise, n/a for n/a.
level() {
    if [[ "$1" == "n/a" ]]; then echo "n/a"; return; fi
    awk -v v="$1" -v t="$2" 'BEGIN { print ((v + 0 >= t + 0) ? "WARNING" : "OK") }'
}

# pct PART WHOLE — percentage with one decimal.
pct() { awk -v p="$1" -v w="$2" 'BEGIN { printf "%.1f", (w > 0 ? p / w * 100 : 0) }'; }

gib() { awk -v k="$1" 'BEGIN { printf "%.1f GiB", k / 1048576 }'; }

# systemd is usable when systemctl exists and /run/systemd/system exists (sd_booted(3)).
systemd_ok=0
systemd_note="systemctl not installed"
if command -v systemctl >/dev/null 2>&1; then
    if [[ -d /run/systemd/system ]]; then
        systemd_ok=1; systemd_note="running"
    else
        systemd_note="not booted with systemd (PID 1 is $(ps -o comm= -p 1 2>/dev/null || echo unknown))"
    fi
fi

# ---------- CPU load ----------
cores="$(nproc 2>/dev/null || echo 0)"
if [[ -r /proc/loadavg ]] && (( cores > 0 )); then
    read -r l1 l5 l15 _ < /proc/loadavg
    cpu_pct="$(awk -v l="$l1" -v c="$cores" 'BEGIN { printf "%.1f", l / c * 100 }')"
    add cpu "load 1/5/15 min $l1 $l5 $l15 on $cores CPU(s)" "${cpu_pct}%" ">= ${CPU_T}%" "$(level "$cpu_pct" "$CPU_T")"
else
    add cpu "load average" "n/a" ">= ${CPU_T}%" "n/a"
fi

# ---------- memory and swap ----------
mem_total=""; mem_avail=""; swap_total=""; swap_free=""
if [[ -r /proc/meminfo ]]; then
    while read -r key val _; do
        case "$key" in
            MemTotal:) mem_total="$val" ;;
            MemAvailable:) mem_avail="$val" ;;
            SwapTotal:) swap_total="$val" ;;
            SwapFree:) swap_free="$val" ;;
        esac
    done < /proc/meminfo
fi
if [[ -n "$mem_total" && -n "$mem_avail" ]] && (( mem_total > 0 )); then
    mem_pct="$(pct "$((mem_total - mem_avail))" "$mem_total")"
    add memory "used of $(gib "$mem_total") (MemTotal - MemAvailable)" "${mem_pct}%" ">= ${MEM_T}%" "$(level "$mem_pct" "$MEM_T")"
else
    add memory "used (MemTotal - MemAvailable)" "n/a" ">= ${MEM_T}%" "n/a"
fi
if [[ -n "$swap_total" && -n "$swap_free" ]] && (( swap_total > 0 )); then
    swap_pct="$(pct "$((swap_total - swap_free))" "$swap_total")"
    add swap "used of $(gib "$swap_total")" "${swap_pct}%" ">= ${MEM_T}%" "$(level "$swap_pct" "$MEM_T")"
else
    add swap "no swap configured" "n/a" ">= ${MEM_T}%" "n/a"
fi

# ---------- filesystems: space and inodes ----------
# Fields: source fstype sizeK use% inodes iuse% mountpoint (mount points may contain spaces).
raw="$(LC_ALL=C df --output=source,fstype,size,pcent,itotal,ipcent,target 2>/dev/null)"
fs_rows="$(awk -v pseudo="$PSEUDO_TYPES" '
    BEGIN { n = split(pseudo, p, /[ \t]+/); for (i = 1; i <= n; i++) skip[p[i]] = 1 }
    NR == 1 { next }
    {
        if (($2 in skip) || $3 == 0) next
        target = ""; for (i = 7; i <= NF; i++) target = target (i > 7 ? " " : "") $i
        if (seen[$1 SUBSEP target]++) next
        use = $4; sub(/%/, "", use); if (use == "-") use = "n/a"
        iuse = $6; sub(/%/, "", iuse); if (iuse == "-" || $5 == 0) iuse = "n/a"
        printf "%s\t%s\t%s\t%s\n", target, $2, use, iuse
    }' <<< "$raw")"
if [[ -n "$fs_rows" ]]; then
    while IFS=$'\t' read -r target fstype use iuse; do
        [[ -n "$target" ]] || continue
        add disk "$target ($fstype)" "$( [[ "$use" == "n/a" ]] && echo n/a || echo "${use}%")" \
            ">= ${DISK_T}%" "$(level "$use" "$DISK_T")"
        add inodes "$target ($fstype)" "$( [[ "$iuse" == "n/a" ]] && echo n/a || echo "${iuse}%")" \
            ">= ${DISK_T}%" "$(level "$iuse" "$DISK_T")"
    done <<< "$fs_rows"
else
    add disk "no real filesystem found (df --output)" "n/a" ">= ${DISK_T}%" "n/a"
fi

# ---------- services (-s) ----------
for u in "${unit_list[@]}"; do
    if (( systemd_ok )); then
        # is-active prints active, inactive, failed, activating... and exits non-zero unless active.
        state="$(systemctl is-active -- "$u" 2>/dev/null)"
        [[ -n "$state" ]] || state="unknown"
        if [[ "$state" == "active" ]]; then st="OK"; else st="WARNING"; fi
        add service "$u" "$state" "active" "$st"
    else
        add service "$u" "n/a" "active" "n/a"
    fi
done

# ---------- failed systemd units ----------
if (( systemd_ok )) && failed_out="$(systemctl --failed --no-legend --plain 2>/dev/null)"; then
    failed_count="$(grep -c . <<< "$failed_out")"
    failed_names="$(awk 'NF { printf "%s%s", (n++ ? ", " : ""), $1 }' <<< "$failed_out")"
    if (( failed_count > 0 )); then st="WARNING"; else st="OK"; fi
    add failed-units "systemctl --failed${failed_names:+ ($failed_names)}" "$failed_count" "0" "$st"
else
    if (( systemd_ok )); then why="no answer from systemd"; else why="systemd not running"; fi
    add failed-units "systemctl --failed ($why)" "n/a" "0" "n/a"
fi

# ---------- reboot required (Debian/Ubuntu: written by update-notifier-common hooks) ----------
if [[ -e /var/run/reboot-required ]]; then
    pkgs=""
    if [[ -r /var/run/reboot-required.pkgs ]]; then
        pkgs="$(sort -u /var/run/reboot-required.pkgs | awk 'NF { printf "%s%s", (n++ ? ", " : ""), $1 }')"
    fi
    add reboot "/var/run/reboot-required${pkgs:+ (packages: $pkgs)}" "yes" "no" "WARNING"
else
    add reboot "/var/run/reboot-required" "no" "no" "OK"
fi

# ---------- uptime (information) ----------
if [[ -r /proc/uptime ]]; then
    read -r up_s _ < /proc/uptime
    up_s="${up_s%%.*}"
    boot_utc="$(date -u -d "@$(( $(date +%s) - up_s ))" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo n/a)"
    up_txt="$(printf '%dd %02dh %02dm' $((up_s / 86400)) $((up_s % 86400 / 3600)) $((up_s % 3600 / 60)))"
    add uptime "booted $boot_utc" "$up_txt" "-" "OK"
else
    add uptime "/proc/uptime" "n/a" "-" "n/a"
fi

results="${results%$'\n'}"
warnings="$(awk -F'\t' '$5 == "WARNING" {
        printf "%-13s %s: %s (%s %s)\n", $1, $2, $3, ($4 ~ /^>=/ ? "threshold" : "expected"), $4 }' <<< "$results")"
status="OK"
[[ -n "$warnings" ]] && status="WARNING"

host_name="$(hostname 2>/dev/null || echo n/a)"
timestamp_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
count_of() { awk -F'\t' -v s="$1" '$5 == s' <<< "$results" | grep -c .; }

# ---------- rendering ----------
render_text() {
    printf '==============================================\n'
    printf ' System Health Report\n'
    printf '==============================================\n'
    printf '%-20s : %s\n' "Report time (UTC)" "$timestamp_utc" "Host name" "$host_name" \
        "Thresholds" "CPU >= ${CPU_T}%, memory/swap >= ${MEM_T}%, disk/inodes >= ${DISK_T}%" \
        "systemd" "$systemd_note" \
        "Checks" "$(count_of OK) OK, $(count_of WARNING) WARNING, $(count_of n/a) n/a" \
        "Status" "$status"
    printf '\n--- Checks ---\n'
    printf '%-13s %-8s %-11s %-9s %s\n' CHECK STATUS VALUE THRESHOLD ITEM
    local check item value threshold st
    while IFS=$'\t' read -r check item value threshold st; do
        [[ -n "$check" ]] || continue
        printf '%-13s %-8s %-11s %-9s %s\n' "$check" "$st" "$value" "$threshold" "$item"
    done <<< "$results"
    printf '\n--- Warnings ---\n'
    if [[ -n "$warnings" ]]; then printf '%s\n' "$warnings"; else printf 'none\n'; fi
}

csv_escape() {
    local s="${1//\"/\"\"}"
    printf '"%s"' "$s"
}

render_csv() {
    printf 'Check,Item,Value,Threshold,Status\n'
    local check item value threshold st
    while IFS=$'\t' read -r check item value threshold st; do
        [[ -n "$check" ]] || continue
        printf '%s,%s,%s,%s,%s\n' "$check" "$(csv_escape "$item")" "$(csv_escape "$value")" \
            "$(csv_escape "$threshold")" "$st"
    done <<< "$results"
}

if [[ "$FORMAT" == "csv" ]]; then
    report="$(render_csv)"; ext="csv"
else
    report="$(render_text)"; ext="txt"
fi

# -q: silence on OK so cron only mails when something needs attention.
if (( QUIET == 0 )) || [[ "$status" != "OK" ]]; then
    printf '%s\n' "$report"
fi

if [[ -n "$OUTPUT_DIR" ]]; then
    safe_host="${host_name//[^A-Za-z0-9._-]/_}"
    outfile="$OUTPUT_DIR/system-health-${safe_host}-$(date -u +%Y%m%dT%H%M%SZ).${ext}"
    printf '%s\n' "$report" > "$outfile" || die "failed to write '$outfile'" 2
    if (( QUIET == 0 )); then printf '\nReport saved to: %s\n' "$outfile" >&2; fi
fi

[[ "$status" == "OK" ]] && exit 0
exit 3

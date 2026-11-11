#!/usr/bin/env bash
#
# disk-monitor.sh — Read-only filesystem usage report with warning/critical thresholds.
#
# Course : Linux & PowerShell Professional Mastery (Day 09)
# Target : Ubuntu 24.04 LTS (works on any Linux with GNU coreutils df/du)
# Needs  : bash 4+, GNU coreutils (df --output, du), awk, sort. No root required
#          (du skips directories you cannot read and counts them as "unreadable").
#
# Usage  : ./disk-monitor.sh [-w WARN_PCT] [-c CRIT_PCT] [-i INODE_PCT] [-a] [-m PATH]
#                            [-p PATH] [-n COUNT] [-f text|csv] [-o OUTPUT_DIR] [-h]
#   -w WARN_PCT   Space warning threshold in percent, 1-100 (default 80)
#   -c CRIT_PCT   Space critical threshold in percent, 1-100, >= WARN (default 90)
#   -i INODE_PCT  Inode warning threshold in percent, 1-100 (default 90)
#   -a            Include pseudo/virtual filesystems (tmpfs, squashfs, overlay...)
#   -m PATH       Only check the filesystem that contains PATH (any type; default: all)
#   -p PATH       Also list the largest directories directly under PATH (du -x, one level)
#   -n COUNT      Number of directories to list with -p, 1-50 (default 10)
#   -f FMT        Output format: text (default) or csv
#   -o DIR        Also save the report to DIR/disk-monitor-<host>-<UTC timestamp>.<ext>
#   -h            Show this help
#
# Exit codes: 0 OK · 1 invalid arguments · 2 output directory problem
#             3 at least one filesystem is at or above a threshold
#
# Safety: this script only READS (df, du). It never deletes, moves or changes files.

set -o nounset
set -o pipefail

readonly SCRIPT_NAME="${0##*/}"
WARN=80
CRIT=90
INODE_T=90
ALL_FS=0
DU_PATH=""
COUNT=10
FORMAT="text"
OUTPUT_DIR=""
ONLY_PATH=""

# Filesystem types that describe memory, packages or kernel interfaces, not disks.
readonly PSEUDO_TYPES="tmpfs devtmpfs squashfs overlay proc sysfs cgroup cgroup2 devpts \
mqueue debugfs tracefs securityfs pstore efivarfs bpf autofs fusectl configfs hugetlbfs \
ramfs nsfs binfmt_misc rpc_pipefs fuse.portal fuse.gvfsd-fuse fuse.snapfuse"

usage() {
    sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
}

die() {
    printf '%s: error: %s\n' "$SCRIPT_NAME" "$1" >&2
    exit "${2:-1}"
}

is_int() { [[ "$1" =~ ^[0-9]+$ ]]; }
# in_range VALUE MIN MAX — true when VALUE is a whole number between MIN and MAX.
in_range() { is_int "$1" && (( 10#$1 >= $2 && 10#$1 <= $3 )); }

# ---------- argument parsing ----------
while getopts ":w:c:i:am:p:n:f:o:h" opt; do
    case "$opt" in
        w) WARN="$OPTARG" ;;
        c) CRIT="$OPTARG" ;;
        i) INODE_T="$OPTARG" ;;
        a) ALL_FS=1 ;;
        m) ONLY_PATH="$OPTARG" ;;
        p) DU_PATH="$OPTARG" ;;
        n) COUNT="$OPTARG" ;;
        f) FORMAT="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        h) usage; exit 0 ;;
        :) die "option -$OPTARG requires an argument" ;;
        \?) die "unknown option -$OPTARG (use -h for help)" ;;
    esac
done
shift $((OPTIND - 1))
[[ $# -eq 0 ]] || die "unexpected argument '$1' (use -h for help)"

if ! in_range "$WARN" 1 100; then die "-w must be an integer from 1 to 100"; fi
if ! in_range "$CRIT" 1 100; then die "-c must be an integer from 1 to 100"; fi
if ! in_range "$INODE_T" 1 100; then die "-i must be an integer from 1 to 100"; fi
if ! in_range "$COUNT" 1 50; then die "-n must be an integer from 1 to 50"; fi
WARN=$((10#$WARN)); CRIT=$((10#$CRIT)); INODE_T=$((10#$INODE_T)); COUNT=$((10#$COUNT))
(( CRIT >= WARN )) || die "-c ($CRIT) must be greater than or equal to -w ($WARN)"
case "$FORMAT" in
    text|csv) ;;
    *) die "invalid format '$FORMAT' (expected text or csv)" ;;
esac
if [[ -n "$ONLY_PATH" ]]; then
    [[ -e "$ONLY_PATH" ]] || die "-m '$ONLY_PATH' does not exist"
    ALL_FS=1    # the user asked for this filesystem explicitly, whatever its type
fi
if [[ -n "$DU_PATH" ]]; then
    [[ -d "$DU_PATH" ]] || die "-p '$DU_PATH' is not a directory"
    [[ -r "$DU_PATH" && -x "$DU_PATH" ]] || die "-p '$DU_PATH' is not readable"
fi

if [[ -n "$OUTPUT_DIR" ]]; then
    mkdir -p -- "$OUTPUT_DIR" 2>/dev/null || die "cannot create output directory '$OUTPUT_DIR'" 2
    [[ -w "$OUTPUT_DIR" ]] || die "output directory '$OUTPUT_DIR' is not writable" 2
fi

command -v df >/dev/null 2>&1 || die "df (coreutils) is required but not installed" 1

# ---------- filesystem table ----------
# df --output is GNU coreutils 8.21+ (it cannot be combined with -P). Sizes are 1024-byte blocks.
# Mount points with spaces are shown by df as-is, so 'target' is read as "the rest of the line".
df_args=()
[[ -n "$ONLY_PATH" ]] && df_args=(-- "$ONLY_PATH")
raw="$(LC_ALL=C df --output=source,fstype,size,used,avail,pcent,itotal,iused,ipcent,target "${df_args[@]}" 2>/dev/null)"
if [[ -z "$raw" ]]; then
    die "df --output failed (GNU coreutils 8.21 or later is required)" 1
fi

# Fields: source fstype sizeK usedK availK use% inodes iused iuse% mountpoint
rows="$(awk -v all="$ALL_FS" -v pseudo="$PSEUDO_TYPES" '
    BEGIN { n = split(pseudo, p, /[ \t]+/); for (i = 1; i <= n; i++) skip[p[i]] = 1 }
    NR == 1 { next }
    {
        if (!all && ($2 in skip)) next
        if ($3 == 0) next                                  # size 0: not a real filesystem
        target = ""; for (i = 10; i <= NF; i++) target = target (i > 10 ? " " : "") $i
        if (seen[$1 SUBSEP target]++) next                 # bind mounts listed twice
        pct = $6; sub(/%/, "", pct); if (pct == "-") pct = "n/a"
        ipct = $9; sub(/%/, "", ipct); if (ipct == "-" || $7 == 0) ipct = "n/a"
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", $1, $2, $3, $4, $5, pct, ipct, target
    }' <<< "$raw")"

host_name="$(hostname 2>/dev/null || echo n/a)"
timestamp_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
fs_count="$(grep -c . <<< "$rows")"

# Level per filesystem: OK / WARNING / CRITICAL (space) and INODES (inode warning).
evaluated="$(awk -F'\t' -v w="$WARN" -v c="$CRIT" -v it="$INODE_T" '
    {
        level = "OK"
        if ($6 != "n/a" && $6 + 0 >= c) level = "CRITICAL"
        else if ($6 != "n/a" && $6 + 0 >= w) level = "WARNING"
        if ($7 != "n/a" && $7 + 0 >= it) level = (level == "OK" ? "INODES" : level "+INODES")
        printf "%s\t%s\n", $0, level
    }' <<< "$rows")"

breaches="$(awk -F'\t' '$9 != "OK" {
        printf "%-15s %s used %s%%, inodes %s%% (%s, %s)\n", $9, $8, $6, $7, $1, $2 }' <<< "$evaluated")"

status="OK"
if grep -q 'CRITICAL' <<< "$breaches"; then status="CRITICAL"
elif [[ -n "$breaches" ]]; then status="WARNING"
fi

# ---------- optional: largest directories under -p PATH ----------
dirs=""
unreadable=0
if [[ -n "$DU_PATH" ]]; then
    if command -v du >/dev/null 2>&1; then
        du_err="$(mktemp 2>/dev/null || echo "")"
        # -x stays on one filesystem, -d 1 = one level, -k = KiB. Errors (permission denied) are counted.
        if [[ -n "$du_err" ]]; then
            dirs="$(LC_ALL=C du -x -k -d 1 -- "$DU_PATH" 2>"$du_err" | sort -k1,1nr | head -n "$((COUNT + 1))")"
            unreadable="$(grep -c 'Permission denied' "$du_err" || true)"
            rm -f -- "$du_err"
        else
            dirs="$(LC_ALL=C du -x -k -d 1 -- "$DU_PATH" 2>/dev/null | sort -k1,1nr | head -n "$((COUNT + 1))")"
            unreadable="n/a"
        fi
    else
        dirs=""
        unreadable="n/a (du not installed)"
    fi
fi

# ---------- rendering ----------
human() {
    # KiB -> human-readable with one decimal (K, M, G, T)
    awk -v k="$1" 'BEGIN { split("K M G T P", u, " "); i = 1
        while (k >= 1024 && i < 5) { k /= 1024; i++ }
        printf (i == 1 ? "%d%s" : "%.1f%s"), k, u[i] }'
}

render_text() {
    printf '==============================================\n'
    printf ' Disk Monitor Report\n'
    printf '==============================================\n'
    printf '%-20s : %s\n' "Report time (UTC)" "$timestamp_utc" "Host name" "$host_name" \
        "Filesystems" "$fs_count${ONLY_PATH:+ (only the one holding $ONLY_PATH)}" \
        "Thresholds" "space WARN >= ${WARN}%, CRIT >= ${CRIT}%; inodes >= ${INODE_T}%" \
        "Pseudo filesystems" "$([[ $ALL_FS -eq 1 ]] && echo included || echo excluded)" \
        "Status" "$status"
    printf '\n--- Filesystems ---\n'
    printf '%-22s %-8s %8s %8s %8s %5s %6s %-15s %s\n' FILESYSTEM TYPE SIZE USED AVAIL 'USE%' 'IUSE%' LEVEL MOUNTED_ON
    local src fst size used avail pct ipct target level
    while IFS=$'\t' read -r src fst size used avail pct ipct target level; do
        [[ -n "$src" ]] || continue
        printf '%-22s %-8s %8s %8s %8s %5s %6s %-15s %s\n' "${src:0:22}" "${fst:0:8}" \
            "$(human "$size")" "$(human "$used")" "$(human "$avail")" "$pct" "$ipct" "$level" "$target"
    done <<< "$evaluated"
    printf '\n--- Threshold breaches ---\n'
    if [[ -n "$breaches" ]]; then printf '%s\n' "$breaches"; else printf 'none\n'; fi
    if [[ -n "$DU_PATH" ]]; then
        printf '\n--- Largest directories under %s (du -x, one level) ---\n' "$DU_PATH"
        if [[ -n "$dirs" ]]; then
            local kib path
            while read -r kib path; do
                [[ -n "$kib" ]] || continue
                if [[ "$path" == "$DU_PATH" ]]; then path="$path (total)"; fi
                printf '%10s  %s\n' "$(human "$kib")" "$path"
            done <<< "$dirs"
        else
            printf 'n/a\n'
        fi
        printf 'Unreadable entries skipped: %s\n' "$unreadable"
    fi
}

csv_escape() {
    local s="${1//\"/\"\"}"
    printf '"%s"' "$s"
}

render_csv() {
    printf 'Record,Filesystem,Type,SizeKiB,UsedKiB,AvailKiB,UsePercent,InodeUsePercent,Level,MountedOn\n'
    local src fst size used avail pct ipct target level
    while IFS=$'\t' read -r src fst size used avail pct ipct target level; do
        [[ -n "$src" ]] || continue
        printf 'filesystem,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' "$(csv_escape "$src")" "$fst" "$size" "$used" \
            "$avail" "$pct" "$ipct" "$level" "$(csv_escape "$target")"
    done <<< "$evaluated"
    if [[ -n "$DU_PATH" && -n "$dirs" ]]; then
        local kib path
        while read -r kib path; do
            [[ -n "$kib" ]] || continue
            printf 'directory,,,%s,%s,,,,,%s\n' "$kib" "$kib" "$(csv_escape "$path")"
        done <<< "$dirs"
    fi
}

if [[ "$FORMAT" == "csv" ]]; then
    report="$(render_csv)"; ext="csv"
else
    report="$(render_text)"; ext="txt"
fi

printf '%s\n' "$report"

if [[ -n "$OUTPUT_DIR" ]]; then
    safe_host="${host_name//[^A-Za-z0-9._-]/_}"
    outfile="$OUTPUT_DIR/disk-monitor-${safe_host}-$(date -u +%Y%m%dT%H%M%SZ).${ext}"
    printf '%s\n' "$report" > "$outfile" || die "failed to write '$outfile'" 2
    printf '\nReport saved to: %s\n' "$outfile" >&2
fi

[[ "$status" == "OK" ]] && exit 0
exit 3

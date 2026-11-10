#!/usr/bin/env bash
#
# process-monitor.sh — Read-only report of the top CPU and memory processes, with thresholds.
#
# Course : Linux & PowerShell Professional Mastery (Day 08)
# Target : Ubuntu 24.04 LTS (works on any Linux with /proc and procps)
# Needs  : bash 4+, procps (ps), coreutils. No root required (other users' commands
#          may show as n/a when /proc is restricted with hidepid).
#
# Usage  : ./process-monitor.sh [-n COUNT] [-c CPU_PCT] [-m MEM_PCT] [-i SECONDS]
#                               [-f text|csv] [-o OUTPUT_DIR] [-h]
#   -n COUNT    Processes to show per list, 1-100 (default 10)
#   -c CPU_PCT  CPU warning threshold in percent of ONE core, 1-10000 (default 90)
#   -m MEM_PCT  Memory warning threshold in percent of RAM, 1-100 (default 50)
#   -i SECONDS  CPU sampling interval, 0-60 (default 1). 0 = use the ps lifetime average
#   -f FMT      Output format: text (default) or csv
#   -o DIR      Also save the report to DIR/process-monitor-<host>-<UTC timestamp>.<ext>
#   -h          Show this help
#
# Exit codes: 0 OK · 1 invalid arguments · 2 output directory problem
#             3 at least one process is at or above a threshold
#
# Safety: this script only READS /proc and runs ps. It never signals or changes a process.

set -o nounset
set -o pipefail

readonly SCRIPT_NAME="${0##*/}"
COUNT=10
CPU_T=90
MEM_T=50
INTERVAL=1
FORMAT="text"
OUTPUT_DIR=""

usage() {
    sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'
}

die() {
    printf '%s: error: %s\n' "$SCRIPT_NAME" "$1" >&2
    exit "${2:-1}"
}

is_int() { [[ "$1" =~ ^[0-9]+$ ]]; }

# ---------- argument parsing ----------
while getopts ":n:c:m:i:f:o:h" opt; do
    case "$opt" in
        n) COUNT="$OPTARG" ;;
        c) CPU_T="$OPTARG" ;;
        m) MEM_T="$OPTARG" ;;
        i) INTERVAL="$OPTARG" ;;
        f) FORMAT="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        h) usage; exit 0 ;;
        :) die "option -$OPTARG requires an argument" ;;
        \?) die "unknown option -$OPTARG (use -h for help)" ;;
    esac
done
shift $((OPTIND - 1))
[[ $# -eq 0 ]] || die "unexpected argument '$1' (use -h for help)"

# in_range VALUE MIN MAX — true when VALUE is a whole number between MIN and MAX.
in_range() { is_int "$1" && (( 10#$1 >= $2 && 10#$1 <= $3 )); }
if ! in_range "$COUNT" 1 100; then die "-n must be an integer from 1 to 100"; fi
if ! in_range "$CPU_T" 1 10000; then die "-c must be an integer from 1 to 10000"; fi
if ! in_range "$MEM_T" 1 100; then die "-m must be an integer from 1 to 100"; fi
if ! in_range "$INTERVAL" 0 60; then die "-i must be an integer from 0 to 60"; fi
COUNT=$((10#$COUNT)); CPU_T=$((10#$CPU_T)); MEM_T=$((10#$MEM_T)); INTERVAL=$((10#$INTERVAL))
case "$FORMAT" in
    text|csv) ;;
    *) die "invalid format '$FORMAT' (expected text or csv)" ;;
esac

if [[ -n "$OUTPUT_DIR" ]]; then
    mkdir -p -- "$OUTPUT_DIR" 2>/dev/null || die "cannot create output directory '$OUTPUT_DIR'" 2
    [[ -w "$OUTPUT_DIR" ]] || die "output directory '$OUTPUT_DIR' is not writable" 2
fi

command -v ps >/dev/null 2>&1 || die "ps (procps) is required but not installed" 1

# ---------- CPU sampling ----------
# Prints "PID TICKS" for every process, where TICKS = utime + stime from /proc/PID/stat.
# The command name (field 2) may contain spaces and ')' so we cut at the LAST ')'.
sample_ticks() {
    local f line rest pid
    local -a fld
    for f in /proc/[0-9]*/stat; do
        line=""
        read -r line < "$f" 2>/dev/null || continue
        [[ -n "$line" ]] || continue
        pid="${f#/proc/}"; pid="${pid%/stat}"
        rest="${line##*) }"
        read -r -a fld <<< "$rest"
        # fld[0]=state ... fld[11]=utime fld[12]=stime (fields 14 and 15 of proc(5))
        (( ${#fld[@]} > 12 )) || continue
        printf '%s %s\n' "$pid" "$(( fld[11] + fld[12] ))"
    done
}

declare -A cpu_pct=()
cpu_method="ps lifetime average"
clk_tck="$(getconf CLK_TCK 2>/dev/null || echo 100)"
if (( INTERVAL > 0 )) && [[ -r /proc/self/stat ]]; then
    declare -A t1=()
    up1="$(cut -d' ' -f1 /proc/uptime 2>/dev/null || echo 0)"
    while read -r pid ticks; do t1[$pid]=$ticks; done < <(sample_ticks)
    sleep "$INTERVAL"
    up2="$(cut -d' ' -f1 /proc/uptime 2>/dev/null || echo 0)"
    # Real elapsed seconds between the two samples (falls back to the requested interval).
    elapsed="$(awk -v a="$up1" -v b="$up2" -v i="$INTERVAL" 'BEGIN { d = b - a; if (d <= 0) d = i; print d }')"
    while read -r pid ticks; do
        [[ -n "${t1[$pid]:-}" ]] || continue
        # percent of one core = delta_ticks / (CLK_TCK * elapsed) * 100, one decimal
        cpu_pct[$pid]="$(awk -v d="$(( ticks - t1[$pid] ))" -v hz="$clk_tck" -v s="$elapsed" \
            'BEGIN { v = d / (hz * s) * 100; if (v < 0) v = 0; printf "%.1f", v }')"
    done < <(sample_ticks)
    cpu_method="${INTERVAL}s sample of /proc/PID/stat"
fi

# ---------- process table ----------
# pid user %cpu %mem rss stat etime args  (args last because it contains spaces)
table="$(ps -e -o pid=,user:20=,%cpu=,%mem=,rss=,stat=,etime=,args= 2>/dev/null)" \
    || die "ps failed to list processes" 1

self=$$
rows="$(awk -v self="$self" '
    { pid=$1; if (pid == self) next
      if ($8 == "ps" && $9 == "-e" && $11 ~ /^pid=,user:20=/) next   # our own ps call
      cmd=""; for (i = 8; i <= NF; i++) cmd = cmd (i > 8 ? " " : "") $i
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", pid, $2, $3, $4, $5, $6, $7, cmd }' <<< "$table")"

# Replace the ps lifetime %CPU with the sampled value where we have one.
if (( ${#cpu_pct[@]} > 0 )); then
    merged=""
    while IFS=$'\t' read -r pid user pcpu pmem rss stat etime cmd; do
        [[ -n "$pid" ]] || continue
        pcpu="${cpu_pct[$pid]:-$pcpu}"
        merged+="$pid"$'\t'"$user"$'\t'"$pcpu"$'\t'"$pmem"$'\t'"$rss"$'\t'"$stat"$'\t'"$etime"$'\t'"$cmd"$'\n'
    done <<< "$rows"
    rows="${merged%$'\n'}"
fi

top_cpu="$(sort -t $'\t' -k3,3gr <<< "$rows" | head -n "$COUNT")"
top_mem="$(sort -t $'\t' -k4,4gr -k5,5nr <<< "$rows" | head -n "$COUNT")"

total_procs="$(grep -c . <<< "$rows")"
zombies="$(awk -F'\t' '$6 ~ /^Z/' <<< "$rows" | grep -c .)"
load_avg="n/a"
[[ -r /proc/loadavg ]] && load_avg="$(cut -d' ' -f1-3 /proc/loadavg)"
cores="$(nproc 2>/dev/null || echo n/a)"
host_name="$(hostname 2>/dev/null || echo n/a)"
timestamp_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

breaches="$(awk -F'\t' -v c="$CPU_T" -v m="$MEM_T" '
    ($3 + 0 >= c) { printf "CPU %s%% >= %s%%  PID %s (%s) %s\n", $3, c, $1, $2, substr($8, 1, 60) }
    ($4 + 0 >= m) { printf "MEM %s%% >= %s%%  PID %s (%s) %s\n", $4, m, $1, $2, substr($8, 1, 60) }' <<< "$rows")"

status="OK"
[[ -n "$breaches" ]] && status="WARNING"

# ---------- rendering ----------
render_list_text() {
    printf '%7s %-12s %6s %5s %9s %-5s %11s %s\n' PID USER '%CPU' '%MEM' 'RSS(MiB)' STAT ELAPSED COMMAND
    awk -F'\t' '{ printf "%7s %-12s %6s %5s %9.1f %-5s %11s %s\n",
                  $1, substr($2, 1, 12), $3, $4, $5 / 1024, $6, $7, substr($8, 1, 60) }' <<< "$1"
}

render_text() {
    printf '==============================================\n'
    printf ' Process Monitor Report\n'
    printf '==============================================\n'
    printf '%-24s : %s\n' "Report time (UTC)" "$timestamp_utc" "Host name" "$host_name" \
        "Processes" "$total_procs" "Zombie processes" "$zombies" "CPU cores" "$cores" \
        "Load average (1/5/15)" "$load_avg" "CPU method" "$cpu_method" \
        "Thresholds" "CPU >= ${CPU_T}% of one core, MEM >= ${MEM_T}% of RAM" "Status" "$status"
    printf '\n--- Top %s by CPU ---\n' "$COUNT"
    render_list_text "$top_cpu"
    printf '\n--- Top %s by memory ---\n' "$COUNT"
    render_list_text "$top_mem"
    printf '\n--- Threshold breaches ---\n'
    if [[ -n "$breaches" ]]; then printf '%s\n' "$breaches"; else printf 'none\n'; fi
}

csv_escape() {
    local s="${1//\"/\"\"}"
    printf '"%s"' "$s"
}

render_csv() {
    printf 'List,PID,User,CpuPercent,MemPercent,RssKiB,State,Elapsed,Command\n'
    local list data pid user pcpu pmem rss stat etime cmd
    for list in cpu memory; do
        if [[ "$list" == cpu ]]; then data="$top_cpu"; else data="$top_mem"; fi
        while IFS=$'\t' read -r pid user pcpu pmem rss stat etime cmd; do
            [[ -n "$pid" ]] || continue
            printf '%s,%s,%s,%s,%s,%s,%s,%s,%s\n' "$list" "$pid" "$(csv_escape "$user")" \
                "$pcpu" "$pmem" "$rss" "$stat" "$etime" "$(csv_escape "$cmd")"
        done <<< "$data"
    done
}

if [[ "$FORMAT" == "csv" ]]; then
    report="$(render_csv)"; ext="csv"
else
    report="$(render_text)"; ext="txt"
fi

printf '%s\n' "$report"

if [[ -n "$OUTPUT_DIR" ]]; then
    safe_host="${host_name//[^A-Za-z0-9._-]/_}"
    outfile="$OUTPUT_DIR/process-monitor-${safe_host}-$(date -u +%Y%m%dT%H%M%SZ).${ext}"
    printf '%s\n' "$report" > "$outfile" || die "failed to write '$outfile'" 2
    printf '\nReport saved to: %s\n' "$outfile" >&2
fi

[[ "$status" == "OK" ]] && exit 0
exit 3

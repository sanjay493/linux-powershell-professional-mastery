#!/usr/bin/env bash
#
# port-monitor.sh — Read-only report of listening TCP/UDP ports and their owning processes,
#                   with an exposure check and a baseline comparison.
#
# Course : Linux & PowerShell Professional Mastery (Day 14)
# Target : Ubuntu 24.04 LTS (works on any Linux with iproute2 'ss'; falls back to
#          net-tools 'netstat', then to /proc/net/{tcp,tcp6,udp,udp6})
# Needs  : bash 4+, awk, sort, ps. No root required, but without root the owning process
#          of sockets that belong to OTHER users is shown as "n/a" (run with sudo to see all).
#
# Usage  : ./port-monitor.sh [-t] [-u] [-e] [-a PORTS] [-c] [-b BASELINE] [-s BASELINE]
#                            [-f text|csv] [-o OUTPUT_DIR] [-h]
#   -t            TCP listeners only
#   -u            UDP endpoints only (default: TCP and UDP)
#   -e            Exposure check: flag listeners bound to ALL addresses (0.0.0.0, ::, *)
#                 whose port is not in the allowed list (-a)
#   -a PORTS      Comma-separated ports allowed on all addresses with -e (default 22)
#   -c            Also summarise TCP connections by state (ESTAB, TIME-WAIT, CLOSE-WAIT...)
#   -b BASELINE   Compare with a baseline saved earlier with -s: report NEW and GONE listeners
#   -s BASELINE   Save the current listeners as a baseline file (the only file this script
#                 writes apart from -o reports)
#   -f FMT        Output format: text (default) or csv
#   -o DIR        Also save the report to DIR/port-monitor-<host>-<UTC timestamp>.<ext>
#   -h            Show this help
#
# Exit codes: 0 OK · 1 invalid arguments · 2 output/baseline file problem
#             3 threshold breached: a NEW listener compared with -b, or an exposed port with -e
#
# Safety: this script only READS socket tables (ss / netstat / /proc). It never closes
#         sockets, stops processes or changes firewall rules.

set -o nounset
set -o pipefail

readonly SCRIPT_NAME="${0##*/}"
WANT_TCP=1
WANT_UDP=1
OPT_T=0
OPT_U=0
EXPOSURE=0
ALLOWED="22"
CONN_SUMMARY=0
BASELINE_IN=""
BASELINE_OUT=""
FORMAT="text"
OUTPUT_DIR=""

usage() {
    sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'
}

die() {
    printf '%s: error: %s\n' "$SCRIPT_NAME" "$1" >&2
    exit "${2:-1}"
}

# ---------- argument parsing ----------
while getopts ":tuea:cb:s:f:o:h" opt; do
    case "$opt" in
        t) OPT_T=1 ;;
        u) OPT_U=1 ;;
        e) EXPOSURE=1 ;;
        a) ALLOWED="$OPTARG" ;;
        c) CONN_SUMMARY=1 ;;
        b) BASELINE_IN="$OPTARG" ;;
        s) BASELINE_OUT="$OPTARG" ;;
        f) FORMAT="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        h) usage; exit 0 ;;
        :) die "option -$OPTARG requires an argument" ;;
        \?) die "unknown option -$OPTARG (use -h for help)" ;;
    esac
done
shift $((OPTIND - 1))
[[ $# -eq 0 ]] || die "unexpected argument '$1' (use -h for help)"

# -t and -u together mean both, the same as neither.
if (( OPT_T == 1 && OPT_U == 0 )); then WANT_UDP=0; fi
if (( OPT_U == 1 && OPT_T == 0 )); then WANT_TCP=0; fi

case "$FORMAT" in
    text|csv) ;;
    *) die "invalid format '$FORMAT' (expected text or csv)" ;;
esac
[[ "$ALLOWED" =~ ^[0-9]+(,[0-9]+)*$ ]] || die "-a must be a comma-separated list of port numbers (e.g. 22,443)"
IFS=',' read -r -a allowed_list <<< "$ALLOWED"
for p in "${allowed_list[@]}"; do
    (( 10#$p >= 1 && 10#$p <= 65535 )) || die "-a: port '$p' is outside 1-65535"
done
if [[ -n "$BASELINE_IN" ]]; then
    [[ -f "$BASELINE_IN" && -r "$BASELINE_IN" ]] || die "-b '$BASELINE_IN' is not a readable file"
fi
if [[ -n "$BASELINE_OUT" ]]; then
    out_parent="$(dirname -- "$BASELINE_OUT")"
    [[ -d "$out_parent" && -w "$out_parent" ]] || die "cannot write baseline file '$BASELINE_OUT' (directory missing or not writable)" 2
fi
if [[ -n "$OUTPUT_DIR" ]]; then
    mkdir -p -- "$OUTPUT_DIR" 2>/dev/null || die "cannot create output directory '$OUTPUT_DIR'" 2
    [[ -w "$OUTPUT_DIR" ]] || die "output directory '$OUTPUT_DIR' is not writable" 2
fi

# ---------- helpers ----------
# Reads "proto<TAB>address<TAB>port<TAB>process<TAB>pid" lines; prints them sorted and unique.
normalise() { sort -t$'\t' -k1,1 -k3,3n -k2,2 -u; }

# ss: Netid State Recv-Q Send-Q Local:Port Peer:Port [users:(("name",pid=N,fd=N),...)]
collect_ss() {
    # Always ask for both protocols: with only one, ss leaves out the Netid column.
    # -p is harmless without root: it simply shows nothing for other users' sockets.
    LC_ALL=C ss -H -l -n -t -u -p 2>/dev/null | awk -v tcp="$WANT_TCP" -v udp="$WANT_UDP" '
        ($1 == "tcp" && tcp) || ($1 == "udp" && udp) {
            local = $5
            n = split(local, parts, ":"); port = parts[n]
            addr = substr(local, 1, length(local) - length(port) - 1)
            gsub(/^\[|\]$/, "", addr)
            proc = "n/a"; pid = "n/a"
            if (match($0, /users:\(\("[^"]*",pid=[0-9]+/)) {
                s = substr($0, RSTART + 9, RLENGTH - 9)       # name",pid=N
                split(s, f, "\",pid=")
                proc = f[1]; pid = f[2]
            }
            printf "%s\t%s\t%s\t%s\t%s\n", $1, addr, port, proc, pid
        }'
}

# netstat -tulnp: Proto Recv-Q Send-Q Local Foreign [State] PID/Program
collect_netstat() {
    local flags="-l -n -p"
    (( WANT_TCP )) && flags+=" -t"
    (( WANT_UDP )) && flags+=" -u"
    # shellcheck disable=SC2086
    LC_ALL=C netstat $flags 2>/dev/null | awk '
        $1 ~ /^(tcp|udp)6?$/ {
            proto = ($1 ~ /^tcp/) ? "tcp" : "udp"
            local = $4
            n = split(local, parts, ":"); port = parts[n]
            addr = substr(local, 1, length(local) - length(port) - 1)
            prog = $NF; proc = "n/a"; pid = "n/a"
            if (prog ~ /^[0-9]+\//) { pid = prog; sub(/\/.*/, "", pid); proc = prog; sub(/^[0-9]+\//, "", proc) }
            printf "%s\t%s\t%s\t%s\t%s\n", proto, addr, port, proc, pid
        }'
}

# /proc/net/*: hex addresses, st 0A = TCP LISTEN, st 07 = UDP unconnected. No process info.
collect_proc() {
    local f proto
    for f in tcp tcp6 udp udp6; do
        [[ "$f" == tcp* ]] && proto=tcp || proto=udp
        [[ "$proto" == tcp ]] && (( ! WANT_TCP )) && continue
        [[ "$proto" == udp ]] && (( ! WANT_UDP )) && continue
        [[ -r "/proc/net/$f" ]] || continue
        awk -v proto="$proto" -v want="$([[ $proto == tcp ]] && echo 0A || echo 07)" '
            function hex(h,   i, v, c) {
                v = 0; h = toupper(h)
                for (i = 1; i <= length(h); i++) { c = index("0123456789ABCDEF", substr(h, i, 1)) - 1; v = v * 16 + c }
                return v
            }
            function v4(h) { return hex(substr(h,7,2)) "." hex(substr(h,5,2)) "." hex(substr(h,3,2)) "." hex(substr(h,1,2)) }
            function v6(h,   w, i, out, g) {
                if (h == "00000000000000000000000000000000") return "::"
                if (h == "00000000000000000000000001000000") return "::1"
                out = ""
                for (w = 0; w < 4; w++) {
                    g = substr(h, w * 8 + 1, 8)
                    g = substr(g,7,2) substr(g,5,2) substr(g,3,2) substr(g,1,2)   # word is little-endian
                    out = out (w ? ":" : "") tolower(substr(g,1,4)) ":" tolower(substr(g,5,4))
                }
                return out
            }
            NR > 1 && $4 == want {
                split($2, a, ":")
                addr = (length(a[1]) == 8) ? v4(a[1]) : v6(a[1])
                printf "%s\t%s\t%s\tn/a\tn/a\n", proto, addr, hex(a[2])
            }' "/proc/net/$f"
    done
}

# Service names from /etc/services (netbase package); "n/a" when unknown.
declare -A SERVICES=()
if [[ -r /etc/services ]]; then
    while read -r name portproto; do
        [[ -n "${SERVICES[$portproto]:-}" ]] || SERVICES[$portproto]="$name"
    done < <(awk '!/^[[:space:]]*#/ && NF >= 2 { print $1, $2 }' /etc/services)
fi

proc_user() {
    local pid="$1" u
    [[ "$pid" =~ ^[0-9]+$ ]] || { echo "n/a"; return; }
    u="$(ps -o user= -p "$pid" 2>/dev/null | awk '{print $1}')"
    echo "${u:-n/a}"
}

is_wildcard() { [[ "$1" == "0.0.0.0" || "$1" == "::" || "$1" == "*" ]]; }
is_allowed() {
    local p
    for p in "${allowed_list[@]}"; do (( 10#$p == 10#$1 )) && return 0; done
    return 1
}

# ---------- collect ----------
SOURCE="ss"
if command -v ss >/dev/null 2>&1; then
    raw="$(collect_ss)"
elif command -v netstat >/dev/null 2>&1; then
    SOURCE="netstat"; raw="$(collect_netstat)"
else
    SOURCE="/proc/net"; raw="$(collect_proc)"
fi
raw="$(normalise <<< "$raw" | grep -v '^$')"

host_name="$(hostname 2>/dev/null || echo n/a)"
timestamp_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
euid="$(id -u)"

# Enrich: proto addr port service process pid user exposure
rows=""
exposed_count=0
listener_count=0
unknown_proc=0
while IFS=$'\t' read -r proto addr port proc pid; do
    [[ -n "${proto:-}" ]] || continue
    listener_count=$((listener_count + 1))
    svc="${SERVICES[$port/$proto]:-n/a}"
    user="$(proc_user "$pid")"
    [[ "$proc" == "n/a" ]] && unknown_proc=$((unknown_proc + 1))
    if is_wildcard "$addr"; then scope="ALL"
    elif [[ "$addr" == 127.* || "$addr" == "::1" || "$addr" == 127.*%* ]]; then scope="LOOPBACK"
    else scope="SPECIFIC"; fi
    flag="-"
    if (( EXPOSURE )) && [[ "$scope" == "ALL" ]] && ! is_allowed "$port"; then
        flag="EXPOSED"; exposed_count=$((exposed_count + 1))
    fi
    rows+="$proto"$'\t'"$addr"$'\t'"$port"$'\t'"$svc"$'\t'"$proc"$'\t'"$pid"$'\t'"$user"$'\t'"$scope"$'\t'"$flag"$'\n'
done <<< "$raw"

# Baseline key: proto address port (process names can be n/a for non-root, so they are not part of the key).
current_keys="$(awk -F'\t' 'NF { print $1 " " $2 " " $3 }' <<< "$rows" | sort -u)"
new_list=""; gone_list=""; new_count=0; gone_count=0
if [[ -n "$BASELINE_IN" ]]; then
    base_keys="$(grep -v '^[[:space:]]*#' -- "$BASELINE_IN" | awk 'NF >= 3 { print $1 " " $2 " " $3 }' | sort -u)"
    new_list="$(comm -13 <(printf '%s\n' "$base_keys") <(printf '%s\n' "$current_keys") | grep -v '^$')"
    gone_list="$(comm -23 <(printf '%s\n' "$base_keys") <(printf '%s\n' "$current_keys") | grep -v '^$')"
    new_count="$(grep -c . <<< "$new_list")"
    gone_count="$(grep -c . <<< "$gone_list")"
fi

conn_summary=""
if (( CONN_SUMMARY )); then
    if [[ "$SOURCE" == "ss" ]]; then
        conn_summary="$(LC_ALL=C ss -H -t -a -n 2>/dev/null | awk '$1 != "LISTEN" { c[$1]++ } END { for (s in c) print c[s], s }' | sort -rn)"
    elif [[ "$SOURCE" == "netstat" ]]; then
        conn_summary="$(LC_ALL=C netstat -t -a -n 2>/dev/null | awk '$1 ~ /^tcp/ && $6 != "LISTEN" { c[$6]++ } END { for (s in c) print c[s], s }' | sort -rn)"
    else
        conn_summary="$(cat /proc/net/tcp /proc/net/tcp6 2>/dev/null | awk '
            BEGIN { split("01 ESTAB 02 SYN-SENT 03 SYN-RECV 04 FIN-WAIT-1 05 FIN-WAIT-2 06 TIME-WAIT 07 CLOSE 08 CLOSE-WAIT 09 LAST-ACK 0B CLOSING", a, " ")
                    for (i = 1; i < 20; i += 2) name[a[i]] = a[i + 1] }
            $1 ~ /:$/ && $4 != "0A" { c[($4 in name) ? name[$4] : $4]++ }
            END { for (s in c) print c[s], s }' | sort -rn)"
    fi
fi

status="OK"
breach=0
if (( new_count > 0 || exposed_count > 0 )); then status="ALERT"; breach=1; fi

# ---------- report ----------
render_text() {
    local protos=""
    (( WANT_TCP )) && protos+="TCP "
    (( WANT_UDP )) && protos+="UDP"
    echo "=============================================="
    echo " Port Monitor Report"
    echo "=============================================="
    printf '%-20s : %s\n' "Report time (UTC)" "$timestamp_utc"
    printf '%-20s : %s\n' "Host name" "$host_name"
    printf '%-20s : %s\n' "Protocols" "${protos% }"
    printf '%-20s : %s\n' "Data source" "$SOURCE"
    printf '%-20s : %s\n' "Listeners" "$listener_count"
    if (( euid != 0 )); then
        printf '%-20s : %s\n' "Process info" "own processes only ($unknown_proc shown as n/a; run with sudo for all)"
    fi
    if (( EXPOSURE )); then printf '%-20s : %s (allowed on all addresses: %s)\n' "Exposed listeners" "$exposed_count" "$ALLOWED"; fi
    if [[ -n "$BASELINE_IN" ]]; then printf '%-20s : %s (NEW %s, GONE %s)\n' "Baseline" "$BASELINE_IN" "$new_count" "$gone_count"; fi
    printf '%-20s : %s\n' "Status" "$status"
    echo
    echo "--- Listening sockets ---"
    printf '%-5s %-28s %-6s %-14s %-16s %-8s %-10s %-9s %s\n' PROTO ADDRESS PORT SERVICE PROCESS PID USER BOUND_TO FLAG
    if [[ -n "$rows" ]]; then
        while IFS=$'\t' read -r proto addr port svc proc pid user scope flag; do
            [[ -n "${proto:-}" ]] || continue
            printf '%-5s %-28s %-6s %-14s %-16s %-8s %-10s %-9s %s\n' "$proto" "$addr" "$port" "$svc" "$proc" "$pid" "$user" "$scope" "$flag"
        done <<< "$rows"
    else
        echo "(none found)"
    fi
    if [[ -n "$BASELINE_IN" ]]; then
        echo
        echo "--- Compared with baseline ---"
        if (( new_count == 0 && gone_count == 0 )); then echo "No changes."; fi
        if [[ -n "$new_list" ]]; then awk '{ print "NEW   " $0 }' <<< "$new_list"; fi
        if [[ -n "$gone_list" ]]; then awk '{ print "GONE  " $0 }' <<< "$gone_list"; fi
    fi
    if (( CONN_SUMMARY )); then
        echo
        echo "--- TCP connections by state (listeners excluded) ---"
        if [[ -n "$conn_summary" ]]; then awk '{ printf "%7s  %s\n", $1, $2 }' <<< "$conn_summary"; else echo "(none)"; fi
    fi
}

render_csv() {
    echo "timestamp_utc,host,proto,address,port,service,process,pid,user,bound_to,flag"
    while IFS=$'\t' read -r proto addr port svc proc pid user scope flag; do
        [[ -n "${proto:-}" ]] || continue
        printf '%s,%s,%s,"%s",%s,%s,"%s",%s,%s,%s,%s\n' "$timestamp_utc" "$host_name" "$proto" "$addr" "$port" "$svc" "${proc//\"/\"\"}" "$pid" "$user" "$scope" "$flag"
    done <<< "$rows"
    if [[ -n "$new_list" ]]; then
        while read -r proto addr port; do
            printf '%s,%s,%s,"%s",%s,n/a,n/a,n/a,n/a,n/a,NEW\n' "$timestamp_utc" "$host_name" "$proto" "$addr" "$port"
        done <<< "$new_list"
    fi
    if [[ -n "$gone_list" ]]; then
        while read -r proto addr port; do
            printf '%s,%s,%s,"%s",%s,n/a,n/a,n/a,n/a,n/a,GONE\n' "$timestamp_utc" "$host_name" "$proto" "$addr" "$port"
        done <<< "$gone_list"
    fi
}

if [[ "$FORMAT" == "csv" ]]; then report="$(render_csv)"; ext="csv"; else report="$(render_text)"; ext="txt"; fi
printf '%s\n' "$report"

if [[ -n "$OUTPUT_DIR" ]]; then
    out_file="$OUTPUT_DIR/port-monitor-${host_name}-$(date -u +%Y%m%dT%H%M%SZ).$ext"
    printf '%s\n' "$report" > "$out_file" 2>/dev/null || die "cannot write report to '$out_file'" 2
    echo "Report saved to: $out_file" >&2
fi

if [[ -n "$BASELINE_OUT" ]]; then
    {
        echo "# port-monitor baseline: proto address port   (host $host_name, $timestamp_utc, source $SOURCE)"
        printf '%s\n' "$current_keys" | grep -v '^$'
    } > "$BASELINE_OUT" 2>/dev/null || die "cannot write baseline file '$BASELINE_OUT'" 2
    echo "Baseline saved to: $BASELINE_OUT ($listener_count listeners)" >&2
fi

exit $(( breach ? 3 : 0 ))

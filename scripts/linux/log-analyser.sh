#!/usr/bin/env bash
#
# log-analyser.sh — Read-only summary of the system log for the last N hours: entries by
#                   severity, top programs, top error/warning messages (normalised), kernel
#                   errors, and failed SSH / sudo authentication counts.
#
# Course : Linux & PowerShell Professional Mastery (Day 16)
# Target : Ubuntu 24.04 LTS (systemd journal and/or rsyslog); any Linux with journalctl or a
#          syslog-format text file
# Needs  : bash 4+, awk, sort, date (GNU). Optional: journalctl (systemd), zcat (gzip).
#          No root required: a normal user sees only their own journal entries unless they are
#          in the 'adm' or 'systemd-journal' group, and /var/log/syslog and /var/log/auth.log
#          are readable by root and the 'adm' group only. Missing sources are reported as "n/a".
#
# Usage  : ./log-analyser.sh [-l FILE] [-s HOURS] [-n TOP] [-c MAXERR] [-f text|csv]
#                            [-o OUTPUT_DIR] [-h]
#   -l FILE       Analyse this syslog-format file instead (plain text or .gz). Default source:
#                 the systemd journal if it returns entries, else /var/log/syslog, else
#                 /var/log/messages
#   -s HOURS      Time window: the last HOURS hours (default 24, 1-8760). 0 = the whole file
#                 or journal (useful for saved or copied log files)
#   -n TOP        Number of programs and messages in the "top" lists (default 10, 1-100)
#   -c MAXERR     Maximum number of error-level entries (priority err or worse) before the
#                 threshold is breached (default 50)
#   -f FMT        Output format: text (default) or csv
#   -o DIR        Also save the report to DIR/log-analyser-<host>-<UTC timestamp>.<ext>
#   -h            Show this help
#
# Severity: journal entries carry a real PRIORITY (0 emerg ... 7 debug). Text files have no
#           priority field, so severity is INFERRED from keywords: error/fail/critical/panic/
#           fatal/segfault = err, warn = warning, anything else = info. The report says which.
# Time window for text files: RFC 3339 timestamps (Ubuntu 24.04 rsyslog default) and classic
#           "Nov 14 10:00:00" timestamps are compared with the local time of this host.
#
# Exit codes: 0 OK (also when no log source is readable: reported as n/a)
#             1 invalid arguments · 2 output file problem
#             3 threshold breached: more than MAXERR error-level entries in the window
#
# Safety: this script only READS logs. It never rotates, truncates, vacuums or deletes them.

set -o nounset
set -o pipefail

readonly SCRIPT_NAME="${0##*/}"
LOG_FILE=""
HOURS="24"
TOP="10"
MAXERR="50"
FORMAT="text"
OUTPUT_DIR=""

usage() {
    sed -n '2,43p' "$0" | sed 's/^# \{0,1\}//'
}

die() {
    printf '%s: error: %s\n' "$SCRIPT_NAME" "$1" >&2
    exit "${2:-1}"
}

# ---------- argument parsing ----------
while getopts ":l:s:n:c:f:o:h" opt; do
    case "$opt" in
        l) LOG_FILE="$OPTARG" ;;
        s) HOURS="$OPTARG" ;;
        n) TOP="$OPTARG" ;;
        c) MAXERR="$OPTARG" ;;
        f) FORMAT="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        h) usage; exit 0 ;;
        :) die "option -$OPTARG requires an argument" ;;
        \?) die "unknown option -$OPTARG (use -h for help)" ;;
    esac
done
shift $((OPTIND - 1))
[[ $# -eq 0 ]] || die "unexpected argument '$1' (use -h for help)"

case "$FORMAT" in
    text|csv) ;;
    *) die "invalid format '$FORMAT' (expected text or csv)" ;;
esac
if [[ ! "$HOURS" =~ ^[0-9]{1,4}$ ]] || (( 10#$HOURS > 8760 )); then die "-s must be a number of hours 0-8760"; fi
if [[ ! "$TOP" =~ ^[0-9]{1,3}$ ]] || (( 10#$TOP < 1 || 10#$TOP > 100 )); then die "-n must be a number 1-100"; fi
[[ "$MAXERR" =~ ^[0-9]{1,9}$ ]] || die "-c must be a non-negative whole number"
HOURS=$((10#$HOURS)); TOP=$((10#$TOP)); MAXERR=$((10#$MAXERR))
if [[ -n "$LOG_FILE" ]]; then
    [[ -f "$LOG_FILE" && -r "$LOG_FILE" ]] || die "-l '$LOG_FILE' is not a readable file"
fi
if [[ -n "$OUTPUT_DIR" ]]; then
    mkdir -p -- "$OUTPUT_DIR" 2>/dev/null || die "cannot create output directory '$OUTPUT_DIR'" 2
    [[ -d "$OUTPUT_DIR" && -w "$OUTPUT_DIR" ]] || die "output directory '$OUTPUT_DIR' is not writable" 2
fi

host_name="$(hostname 2>/dev/null || echo n/a)"
timestamp_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
if (( HOURS > 0 )); then
    since_local="$(date -d "-$HOURS hours" '+%Y-%m-%d %H:%M:%S')"
    window="last $HOURS h (since $since_local local time)"
else
    since_local=""
    window="all entries"
fi

# ---------- extraction: every source becomes "PRIORITY<TAB>PROGRAM<TAB>MESSAGE" ----------
# systemd journal, JSON output: one object per line; only the fields we need are extracted.
extract_journal() {
    local args=(-q --no-pager -o json)
    [[ -n "$since_local" ]] && args+=(--since "$since_local")
    LC_ALL=C journalctl "${args[@]}" 2>/dev/null | awk '
        function field(name,   re, v) {
            re = "\"" name "\":\"([^\"\\\\]|\\\\.)*\""
            if (match($0, re)) { v = substr($0, RSTART + length(name) + 4, RLENGTH - length(name) - 5); return v }
            return ""
        }
        {
            p = field("PRIORITY"); if (p == "") p = 6
            prog = field("SYSLOG_IDENTIFIER"); if (prog == "") prog = field("_COMM"); if (prog == "") prog = "unknown"
            msg = field("MESSAGE")
            if (msg == "" && $0 ~ /"MESSAGE":\[/) msg = "[binary message]"
            gsub(/\\"/, "\"", msg); gsub(/\\t|\t/, " ", msg); gsub(/\\n/, " ", msg)
            printf "%s\t%s\t%s\n", p, prog, msg
        }'
}

# Syslog text: RFC 3339 ("2026-11-14T10:00:00.123456+00:00 host prog[pid]: msg") or
# classic ("Nov 14 10:00:00 host prog[pid]: msg"). Priority is inferred from keywords.
extract_text() {
    local file="$1" reader=(cat --)
    [[ "$file" == *.gz ]] && reader=(zcat --)
    local cut_iso="" cut_md="" now_md="" wrap=0
    if [[ -n "$since_local" ]]; then
        cut_iso="$(date -d "$since_local" '+%Y-%m-%dT%H:%M:%S')"
        cut_md="$(date -d "$since_local" '+%m%d%H%M%S')"
        now_md="$(date '+%m%d%H%M%S')"
        [[ "$cut_md" > "$now_md" ]] && wrap=1
    fi
    "${reader[@]}" "$file" 2>/dev/null | LC_ALL=C awk -v cut_iso="$cut_iso" -v cut_md="$cut_md" -v now_md="$now_md" -v wrap="$wrap" '
        BEGIN { split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", m, " ")
                for (i = 1; i <= 12; i++) mon[m[i]] = sprintf("%02d", i) }
        {
            if ($1 ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T/) {
                if (cut_iso != "" && substr($1, 1, 19) < cut_iso) next
                tag = $3; start = 4
            } else if (($1 in mon) && $3 ~ /^[0-9][0-9]:[0-9][0-9]:[0-9][0-9]$/) {
                if (cut_md != "") {
                    t = $3; gsub(/:/, "", t)
                    key = mon[$1] sprintf("%02d", $2) t
                    if (wrap == 0 && key < cut_md) next
                    if (wrap == 1 && key < cut_md && key > now_md) next
                }
                tag = $5; start = 6
            } else next
            prog = tag; sub(/\[[0-9]+\]:?$/, "", prog); sub(/:$/, "", prog)
            if (prog == "") prog = "unknown"
            msg = ""
            for (i = start; i <= NF; i++) msg = msg (i > start ? " " : "") $i
            l = tolower(msg)
            if (l ~ /error|fail|critical|panic|fatal|segfault/) p = 3
            else if (l ~ /warn/) p = 4
            else p = 6
            printf "%s\t%s\t%s\n", p, prog, msg
        }'
}

SOURCE="n/a"
SEVERITY_MODE="n/a"
records=""
if [[ -n "$LOG_FILE" ]]; then
    SOURCE="$LOG_FILE"; SEVERITY_MODE="inferred from keywords (text file)"
    records="$(extract_text "$LOG_FILE")"
else
    if command -v journalctl >/dev/null 2>&1; then
        records="$(extract_journal)"
        if [[ -n "$records" ]]; then SOURCE="systemd journal (journalctl)"; SEVERITY_MODE="journal PRIORITY field"; fi
    fi
    if [[ -z "$records" ]]; then
        for f in /var/log/syslog /var/log/messages; do
            if [[ -f "$f" && -r "$f" ]]; then
                SOURCE="$f"; SEVERITY_MODE="inferred from keywords (text file)"
                records="$(extract_text "$f")"
                break
            fi
        done
    fi
fi

# ---------- authentication teaser (Day 17) ----------
# Counted in the analysed records; for the default text source also from /var/log/auth.log.
auth_records="$records"
AUTH_SOURCE="$SOURCE"
if [[ -z "$LOG_FILE" && "$SOURCE" != systemd* ]]; then
    if [[ -f /var/log/auth.log && -r /var/log/auth.log ]]; then
        auth_records="$(extract_text /var/log/auth.log)"; AUTH_SOURCE="/var/log/auth.log"
    else
        AUTH_SOURCE="n/a"
    fi
fi
[[ "$SOURCE" == "n/a" && "$AUTH_SOURCE" == "n/a" ]] && auth_records=""

count_auth() {
    # $1 = program regex, $2 = message regex
    awk -F'\t' -v pr="$1" -v mr="$2" '$2 ~ pr && $3 ~ mr { c++ } END { print c + 0 }' <<< "$auth_records"
}
if [[ "$AUTH_SOURCE" == "n/a" ]]; then
    ssh_failed="n/a"; ssh_invalid="n/a"; sudo_failed="n/a"
else
    ssh_failed="$(count_auth '^sshd' 'Failed (password|publickey) for')"
    ssh_invalid="$(count_auth '^sshd' '^[Ii]nvalid user ')"
    sudo_failed="$(count_auth '^sudo$' 'authentication failure|incorrect password attempt')"
fi

# ---------- summarise ----------
total=0; errors=0
sev_list=""; prog_list=""; msg_list=""; kernel_err=0
if [[ -n "$records" ]]; then
    total="$(grep -c . <<< "$records")"
    errors="$(awk -F'\t' '$1 <= 3 { c++ } END { print c + 0 }' <<< "$records")"
    kernel_err="$(awk -F'\t' '$1 <= 3 && $2 == "kernel" { c++ } END { print c + 0 }' <<< "$records")"
    sev_list="$(awk -F'\t' '
        BEGIN { split("emerg alert crit err warning notice info debug", n, " ") }
        { c[$1]++ }
        END { for (p = 0; p <= 7; p++) if (c[p] > 0) print c[p] "\t" n[p + 1] }' <<< "$records")"
    prog_list="$(awk -F'\t' '{ c[$2]++ } END { for (k in c) print c[k] "\t" k }' <<< "$records" | sort -t$'\t' -k1,1rn -k2,2 | head -n "$TOP")"
    msg_list="$(awk -F'\t' '
        # Numbers become N, except digits that follow a letter (ext4, sda1, eth0 stay as they are).
        function numbers(s,   out, i, c, prev, run, keep) {
            out = ""; prev = ""; run = 0; keep = 0
            for (i = 1; i <= length(s); i++) {
                c = substr(s, i, 1)
                if (c ~ /[0-9]/) {
                    if (keep || prev ~ /[A-Za-z]/) { out = out c; keep = 1 }
                    else if (!run) { out = out "N"; run = 1 }
                } else { out = out c; run = 0; keep = 0 }
                prev = c
            }
            return out
        }
        $1 <= 4 {
            m = $3
            gsub(/0x[0-9A-Fa-f]+/, "X", m)
            # hex strings of 8+ characters (IDs, addresses, hashes); short numbers become N below
            gsub(/[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]+/, "X", m)
            m = numbers(m)
            k = ($1 <= 3 ? "err" : "warning") "\t" $2 ": " substr(m, 1, 120)
            c[k]++
        }
        END { for (k in c) print c[k] "\t" k }' <<< "$records" | sort -t$'\t' -k1,1rn -k3,3 | head -n "$TOP")"
fi

status="OK"
breach=0
if [[ "$SOURCE" == "n/a" ]]; then
    status="n/a (no readable log source)"
elif (( errors > MAXERR )); then
    status="ALERT"; breach=1
fi

# ---------- report ----------
render_text() {
    echo "=============================================="
    echo " Log Analyser Report"
    echo "=============================================="
    printf '%-20s : %s\n' "Report time (UTC)" "$timestamp_utc"
    printf '%-20s : %s\n' "Host name" "$host_name"
    printf '%-20s : %s\n' "Source" "$SOURCE"
    printf '%-20s : %s\n' "Window" "$window"
    printf '%-20s : %s\n' "Severity" "$SEVERITY_MODE"
    printf '%-20s : %s\n' "Entries" "$total"
    printf '%-20s : %s (threshold %s)\n' "Error-level entries" "$errors" "$MAXERR"
    printf '%-20s : %s\n' "Kernel errors" "$kernel_err"
    if (( $(id -u) != 0 )); then
        printf '%-20s : %s\n' "Note" "not root: only logs readable by $(id -un) are included"
    fi
    printf '%-20s : %s\n' "Status" "$status"
    echo
    echo "--- Entries by severity ---"
    if [[ -n "$sev_list" ]]; then awk -F'\t' '{ printf "%7s  %s\n", $1, $2 }' <<< "$sev_list"; else echo "(none)"; fi
    echo
    echo "--- Top $TOP programs ---"
    if [[ -n "$prog_list" ]]; then awk -F'\t' '{ printf "%7s  %s\n", $1, $2 }' <<< "$prog_list"; else echo "(none)"; fi
    echo
    echo "--- Top $TOP error/warning messages (digits -> N, hex -> X) ---"
    if [[ -n "$msg_list" ]]; then awk -F'\t' '{ printf "%7s  %-7s  %s\n", $1, $2, $3 }' <<< "$msg_list"; else echo "(none)"; fi
    echo
    echo "--- Authentication (source: $AUTH_SOURCE; details in Day 17) ---"
    printf '%-28s : %s\n' "SSH failed password/key" "$ssh_failed"
    printf '%-28s : %s\n' "SSH invalid user" "$ssh_invalid"
    printf '%-28s : %s\n' "sudo authentication failures" "$sudo_failed"
}

render_csv() {
    local pre="$timestamp_utc,$host_name"
    echo "timestamp_utc,host,section,item,count"
    printf '%s,summary,"source: %s",%s\n' "$pre" "${SOURCE//\"/\"\"}" "$total"
    printf '%s,summary,error_level_entries,%s\n' "$pre" "$errors"
    printf '%s,summary,kernel_errors,%s\n' "$pre" "$kernel_err"
    printf '%s,summary,threshold,%s\n' "$pre" "$MAXERR"
    while IFS=$'\t' read -r c s; do [[ -n "${c:-}" ]] && printf '%s,severity,%s,%s\n' "$pre" "$s" "$c"; done <<< "$sev_list"
    while IFS=$'\t' read -r c p; do [[ -n "${c:-}" ]] && printf '%s,program,"%s",%s\n' "$pre" "${p//\"/\"\"}" "$c"; done <<< "$prog_list"
    while IFS=$'\t' read -r c s m; do [[ -n "${c:-}" ]] && printf '%s,message_%s,"%s",%s\n' "$pre" "$s" "${m//\"/\"\"}" "$c"; done <<< "$msg_list"
    printf '%s,auth,ssh_failed,%s\n' "$pre" "$ssh_failed"
    printf '%s,auth,ssh_invalid_user,%s\n' "$pre" "$ssh_invalid"
    printf '%s,auth,sudo_failed,%s\n' "$pre" "$sudo_failed"
}

if [[ "$FORMAT" == "csv" ]]; then report="$(render_csv)"; ext="csv"; else report="$(render_text)"; ext="txt"; fi
printf '%s\n' "$report"

if [[ -n "$OUTPUT_DIR" ]]; then
    out_file="$OUTPUT_DIR/log-analyser-${host_name}-$(date -u +%Y%m%dT%H%M%SZ).$ext"
    printf '%s\n' "$report" > "$out_file" 2>/dev/null || die "cannot write report to '$out_file'" 2
    echo "Report saved to: $out_file" >&2
fi

exit $(( breach ? 3 : 0 ))

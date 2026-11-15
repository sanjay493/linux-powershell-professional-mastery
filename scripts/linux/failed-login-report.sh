#!/usr/bin/env bash
#
# failed-login-report.sh — Read-only authentication report for the last N hours: failed SSH
#                          logins, invalid users, accepted logins by method, sudo and su
#                          failures, top source addresses and targeted accounts, addresses
#                          at or over a failure threshold, and "success after failure".
#
# Course : Linux & PowerShell Professional Mastery (Day 17)
# Target : Ubuntu 24.04 LTS (systemd journal and/or rsyslog /var/log/auth.log); RHEL family
#          (/var/log/secure); any Linux with journalctl or an auth-log-format text file
# Needs  : bash 4+, awk, sort, date (GNU). Optional: journalctl (systemd), zcat (gzip).
#          No root required, but a normal user sees only their own journal entries unless
#          they are in the 'adm' or 'systemd-journal' group, and /var/log/auth.log is
#          readable by root and the 'adm' group only. Missing sources are reported as "n/a".
#
# Usage  : ./failed-login-report.sh [-l FILE] [-s HOURS] [-t THRESHOLD] [-n TOP]
#                                   [-f text|csv] [-o OUTPUT_DIR] [-h]
#   -l FILE       Analyse this auth-log-format file instead (plain text or .gz). Default
#                 source: the systemd journal (identifiers sshd, sshd-session, sudo, su,
#                 login) if it returns entries, else /var/log/auth.log, else /var/log/secure.
#                 Rotated files (auth.log.1, *.gz) are only read when given with -l.
#   -s HOURS      Time window: the last HOURS hours (default 24, 1-8760). 0 = the whole file
#                 or journal (useful for saved or copied log files)
#   -t THRESHOLD  Failed attempts from one source address that count as an attack
#                 (default 10, 1-100000)
#   -n TOP        Number of entries in the "top" lists (default 10, 1-100)
#   -f FMT        Output format: text (default) or csv
#   -o DIR        Also save the report to DIR/failed-login-report-<host>-<UTC timestamp>.<ext>
#   -h            Show this help
#
# What is counted (sshd): "Failed password|publickey|keyboard-interactive/pam for [invalid
#           user] USER from IP" = one failed attempt; "Invalid user USER from IP" lines that
#           have no matching "Failed" line for the same address and port (key-only servers)
#           are added as failed attempts too. "Accepted METHOD for USER from IP" = success.
#           sudo: "N incorrect password attempts" and "user NOT in sudoers"; su: "FAILED SU".
# Success after failure: an address that had failed attempts in the window and LATER logged
#           in successfully. It may be a user who mistyped a password, or a guessed password:
#           always investigate.
#
# Exit codes: 0 OK (also when no log source is readable: reported as n/a)
#             1 invalid arguments · 2 output file problem
#             3 alert: a source address reached THRESHOLD failed attempts, or a success
#               after failure was found
#
# Safety: this script only READS logs. It never blocks addresses, locks accounts or changes
#         any file other than the optional report in -o.

set -o nounset
set -o pipefail

readonly SCRIPT_NAME="${0##*/}"
LOG_FILE=""
HOURS="24"
THRESHOLD="10"
TOP="10"
FORMAT="text"
OUTPUT_DIR=""

usage() {
    sed -n '2,46p' "$0" | sed 's/^# \{0,1\}//'
}

die() {
    printf '%s: error: %s\n' "$SCRIPT_NAME" "$1" >&2
    exit "${2:-1}"
}

# ---------- argument parsing ----------
while getopts ":l:s:t:n:f:o:h" opt; do
    case "$opt" in
        l) LOG_FILE="$OPTARG" ;;
        s) HOURS="$OPTARG" ;;
        t) THRESHOLD="$OPTARG" ;;
        n) TOP="$OPTARG" ;;
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
if [[ ! "$THRESHOLD" =~ ^[0-9]{1,6}$ ]] || (( 10#$THRESHOLD < 1 || 10#$THRESHOLD > 100000 )); then die "-t must be a number 1-100000"; fi
if [[ ! "$TOP" =~ ^[0-9]{1,3}$ ]] || (( 10#$TOP < 1 || 10#$TOP > 100 )); then die "-n must be a number 1-100"; fi
HOURS=$((10#$HOURS)); THRESHOLD=$((10#$THRESHOLD)); TOP=$((10#$TOP))
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

# ---------- extraction: every source becomes "TIME<TAB>PROGRAM<TAB>MESSAGE" ----------
readonly AUTH_PROGRAMS='^(sshd|sshd-session|sudo|su|login)$'

extract_journal() {
    local args=(-q --no-pager -o short-iso -t sshd -t sshd-session -t sudo -t su -t login)
    [[ -n "$since_local" ]] && args+=(--since "$since_local")
    LC_ALL=C journalctl "${args[@]}" 2>/dev/null | to_records ""
}

# Reads auth-log lines on stdin. RFC 3339 ("2026-11-15T10:00:00.123456+00:00 host prog[pid]:
# msg", also journalctl -o short-iso) or classic ("Nov 15 10:00:00 host prog[pid]: msg").
to_records() {
    local filter="$1" cut_iso="" cut_md="" now_md="" wrap=0
    if [[ -n "$filter" && -n "$since_local" ]]; then
        cut_iso="$(date -d "$since_local" '+%Y-%m-%dT%H:%M:%S')"
        cut_md="$(date -d "$since_local" '+%m%d%H%M%S')"
        now_md="$(date '+%m%d%H%M%S')"
        [[ "$cut_md" > "$now_md" ]] && wrap=1
    fi
    LC_ALL=C awk -v cut_iso="$cut_iso" -v cut_md="$cut_md" -v now_md="$now_md" -v wrap="$wrap" -v progs="$AUTH_PROGRAMS" '
        BEGIN { split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", m, " ")
                for (i = 1; i <= 12; i++) mon[m[i]] = sprintf("%02d", i) }
        {
            if ($1 ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T/) {
                if (cut_iso != "" && substr($1, 1, 19) < cut_iso) next
                ts = substr($1, 1, 19); tag = $3; start = 4
            } else if (($1 in mon) && $3 ~ /^[0-9][0-9]:[0-9][0-9]:[0-9][0-9]$/) {
                if (cut_md != "") {
                    t = $3; gsub(/:/, "", t)
                    key = mon[$1] sprintf("%02d", $2) t
                    if (wrap == 0 && key < cut_md) next
                    if (wrap == 1 && key < cut_md && key > now_md) next
                }
                ts = $1 " " sprintf("%2d", $2) " " $3; tag = $5; start = 6
            } else next
            prog = tag; sub(/\[[0-9]+\]:?$/, "", prog); sub(/:$/, "", prog)
            if (prog !~ progs) next
            msg = ""
            for (i = start; i <= NF; i++) msg = msg (i > start ? " " : "") $i
            printf "%s\t%s\t%s\n", ts, prog, msg
        }'
}

extract_file() {
    local file="$1" reader=(cat --)
    [[ "$file" == *.gz ]] && reader=(zcat --)
    "${reader[@]}" "$file" 2>/dev/null | to_records "window"
}

SOURCE="n/a"
records=""
if [[ -n "$LOG_FILE" ]]; then
    SOURCE="$LOG_FILE"
    records="$(extract_file "$LOG_FILE")"
else
    if command -v journalctl >/dev/null 2>&1; then
        records="$(extract_journal)"
        [[ -n "$records" ]] && SOURCE="systemd journal (journalctl)"
    fi
    if [[ -z "$records" ]]; then
        for f in /var/log/auth.log /var/log/secure; do
            if [[ -f "$f" && -r "$f" ]]; then
                SOURCE="$f"
                records="$(extract_file "$f")"
                break
            fi
        done
    fi
fi

# ---------- analysis ----------
# Produces tagged lines: S<TAB>name<TAB>value (summary), IP<TAB>addr<TAB>fails<TAB>accounts<TAB>first<TAB>last,
# U<TAB>account<TAB>fails, A<TAB>method<TAB>count, SAF<TAB>time<TAB>addr<TAB>account<TAB>method<TAB>fails_before
analyse() {
    LC_ALL=C awk -F'\t' '
        function addfail(ip, user, ts) {
            fails[ip]++; ufails[user]++; total_fail++
            if (!((ip SUBSEP user) in pair)) { pair[ip, user] = 1; accounts[ip]++ }
            if (!(ip in first)) first[ip] = ts
            last[ip] = ts
        }
        # Returns the word after "from" and the word after "port" in msg via globals IP and PORT.
        function addr(msg,   n, w, i) {
            IP = ""; PORT = ""
            n = split(msg, w, " ")
            for (i = 1; i < n; i++) { if (w[i] == "from" && IP == "") IP = w[i + 1]; if (w[i] == "port") PORT = w[i + 1] }
        }
        $2 ~ /^sshd/ {
            msg = $3
            if (msg ~ /^Failed (password|publickey|keyboard-interactive\/pam|none) for /) {
                s = msg; sub(/^Failed [^ ]+ for /, "", s)
                invalid = (s ~ /^invalid user /); if (invalid) sub(/^invalid user /, "", s)
                user = s; sub(/ from .*$/, "", user)
                if (invalid) user = user " (invalid)"
                addr(msg); if (IP == "") next
                addfail(IP, user, $1); failed_lines++
                if (invalid) failed_invalid++
                matched[IP, PORT] = 1
                seen_fail[IP] = 1
                next
            }
            if (msg ~ /^Invalid user /) {
                s = msg; sub(/^Invalid user /, "", s); user = s; sub(/ from .*$/, "", user)
                if (user == "" || s ~ /^from /) user = "(empty)"
                addr(msg); if (IP == "") next
                invalid_lines++
                n_inv++; inv_ip[n_inv] = IP; inv_port[n_inv] = PORT; inv_user[n_inv] = user " (invalid)"; inv_ts[n_inv] = $1
                seen_fail[IP] = 1
                next
            }
            if (msg ~ /^Accepted [^ ]+ for /) {
                method = msg; sub(/^Accepted /, "", method); sub(/ .*$/, "", method)
                s = msg; sub(/^Accepted [^ ]+ for /, "", s); user = s; sub(/ from .*$/, "", user)
                addr(msg)
                accepted++; amethod[method]++
                if (IP != "" && (IP in seen_fail)) {
                    saf++
                    saf_line[saf] = $1 "\t" IP "\t" user "\t" method
                    saf_ip[saf] = IP
                }
                next
            }
            if (msg ~ /maximum authentication attempts exceeded/) { maxauth++; next }
            next
        }
        $2 == "sudo" {
            if ($3 ~ /incorrect password attempt/) { sudo_fail++; next }
            if ($3 ~ /NOT in sudoers/) { sudo_notsudoers++; next }
            if ($3 ~ /COMMAND=/ && $3 !~ /authentication failure/) { sudo_ok++; next }
            next
        }
        $2 == "su" {
            if ($3 ~ /^FAILED SU/ || $3 ~ /^FAILED su/) { su_fail++; next }
            next
        }
        $2 == "login" {
            if ($3 ~ /^FAILED LOGIN/) { login_fail++; next }
            next
        }
        END {
            for (i = 1; i <= n_inv; i++)
                if (!((inv_ip[i], inv_port[i]) in matched)) { addfail(inv_ip[i], inv_user[i], inv_ts[i]); invalid_only++ }
            print "S\tssh_failed_attempts\t" (total_fail + 0)
            print "S\tssh_failed_lines\t" (failed_lines + 0)
            print "S\tssh_invalid_user_lines\t" (invalid_lines + 0)
            print "S\tssh_invalid_without_failed_line\t" (invalid_only + 0)
            print "S\tssh_max_auth_exceeded\t" (maxauth + 0)
            print "S\tssh_accepted\t" (accepted + 0)
            print "S\tsudo_incorrect_password_events\t" (sudo_fail + 0)
            print "S\tsudo_not_in_sudoers\t" (sudo_notsudoers + 0)
            print "S\tsudo_commands_run\t" (sudo_ok + 0)
            print "S\tsu_failed\t" (su_fail + 0)
            print "S\tlogin_failed\t" (login_fail + 0)
            for (ip in fails) print "IP\t" ip "\t" fails[ip] "\t" accounts[ip] "\t" first[ip] "\t" last[ip]
            for (u in ufails) print "U\t" u "\t" ufails[u]
            for (m2 in amethod) print "A\t" m2 "\t" amethod[m2]
            for (i = 1; i <= saf; i++) print "SAF\t" saf_line[i] "\t" fails[saf_ip[i]]
        }' <<< "$records"
}

summary_value() { awk -F'\t' -v k="$1" '$1 == "S" && $2 == k { print $3 }' <<< "$analysis"; }

analysis=""
ip_list=""; user_list=""; method_list=""; saf_list=""; over_list=""
if [[ "$SOURCE" != "n/a" ]]; then
    analysis="$(analyse)"
    ip_list="$(awk -F'\t' '$1 == "IP" { print $3 "\t" $4 "\t" $2 "\t" $5 "\t" $6 }' <<< "$analysis" | sort -t$'\t' -k1,1rn -k3,3)"
    user_list="$(awk -F'\t' '$1 == "U" { print $3 "\t" $2 }' <<< "$analysis" | sort -t$'\t' -k1,1rn -k2,2 | head -n "$TOP")"
    method_list="$(awk -F'\t' '$1 == "A" { print $3 "\t" $2 }' <<< "$analysis" | sort -t$'\t' -k1,1rn -k2,2)"
    saf_list="$(awk -F'\t' '$1 == "SAF" { print $2 "\t" $3 "\t" $4 "\t" $5 "\t" $6 }' <<< "$analysis")"
    over_list="$(awk -F'\t' -v t="$THRESHOLD" '$1 >= t' <<< "$ip_list")"
fi

val() { if [[ "$SOURCE" == "n/a" ]]; then echo "n/a"; else summary_value "$1"; fi; }
ssh_failed="$(val ssh_failed_attempts)"
ssh_invalid="$(val ssh_invalid_user_lines)"
ssh_maxauth="$(val ssh_max_auth_exceeded)"
ssh_accepted="$(val ssh_accepted)"
sudo_fail="$(val sudo_incorrect_password_events)"
sudo_nots="$(val sudo_not_in_sudoers)"
sudo_ok="$(val sudo_commands_run)"
su_fail="$(val su_failed)"
login_fail="$(val login_failed)"
distinct_ips=0
[[ -n "$ip_list" ]] && distinct_ips="$(grep -c . <<< "$ip_list")"
over_count=0
[[ -n "$over_list" ]] && over_count="$(grep -c . <<< "$over_list")"
saf_count=0
[[ -n "$saf_list" ]] && saf_count="$(grep -c . <<< "$saf_list")"

status="OK"
breach=0
if [[ "$SOURCE" == "n/a" ]]; then
    status="n/a (no readable authentication log)"
elif (( over_count > 0 || saf_count > 0 )); then
    status="ALERT"; breach=1
fi

# ---------- report ----------
render_text() {
    echo "=============================================="
    echo " Failed Login Report"
    echo "=============================================="
    printf '%-30s : %s\n' "Report time (UTC)" "$timestamp_utc"
    printf '%-30s : %s\n' "Host name" "$host_name"
    printf '%-30s : %s\n' "Source" "$SOURCE"
    printf '%-30s : %s\n' "Window" "$window"
    printf '%-30s : %s\n' "SSH failed attempts" "$ssh_failed"
    printf '%-30s : %s\n' "SSH invalid-user lines" "$ssh_invalid"
    printf '%-30s : %s\n' "SSH max auth attempts exceeded" "$ssh_maxauth"
    printf '%-30s : %s\n' "SSH accepted logins" "$ssh_accepted"
    printf '%-30s : %s\n' "sudo incorrect password events" "$sudo_fail"
    printf '%-30s : %s\n' "sudo user NOT in sudoers" "$sudo_nots"
    printf '%-30s : %s\n' "sudo commands run" "$sudo_ok"
    printf '%-30s : %s\n' "su failures" "$su_fail"
    printf '%-30s : %s\n' "Console login failures" "$login_fail"
    printf '%-30s : %s\n' "Distinct failing addresses" "$distinct_ips"
    printf '%-30s : %s (threshold %s)\n' "Addresses at/over threshold" "$over_count" "$THRESHOLD"
    printf '%-30s : %s\n' "Success after failure" "$saf_count"
    if (( $(id -u) != 0 )); then
        printf '%-30s : %s\n' "Note" "not root: only logs readable by $(id -un) are included"
    fi
    printf '%-30s : %s\n' "Status" "$status"
    echo
    echo "--- Accepted logins by method ---"
    if [[ -n "$method_list" ]]; then awk -F'\t' '{ printf "%7s  %s\n", $1, $2 }' <<< "$method_list"; else echo "(none)"; fi
    echo
    echo "--- Top $TOP source addresses of failed attempts ---"
    if [[ -n "$ip_list" ]]; then
        printf '%7s  %8s  %-39s  %-19s  %s\n' "fails" "accounts" "address" "first" "last"
        head -n "$TOP" <<< "$ip_list" | awk -F'\t' '{ printf "%7s  %8s  %-39s  %-19s  %s\n", $1, $2, $3, $4, $5 }'
    else echo "(none)"; fi
    echo
    echo "--- Top $TOP targeted accounts ---"
    if [[ -n "$user_list" ]]; then awk -F'\t' '{ printf "%7s  %s\n", $1, $2 }' <<< "$user_list"; else echo "(none)"; fi
    echo
    echo "--- Addresses with $THRESHOLD or more failed attempts ---"
    if [[ -n "$over_list" ]]; then awk -F'\t' '{ printf "%7s  %s  (%s accounts)\n", $1, $3, $2 }' <<< "$over_list"; else echo "(none)"; fi
    echo
    echo "--- Success after failure (investigate!) ---"
    if [[ -n "$saf_list" ]]; then
        awk -F'\t' '{ printf "%s  %s  user=%s  method=%s  failures_from_address=%s\n", $1, $2, $3, $4, $5 }' <<< "$saf_list"
    else echo "(none)"; fi
}

csv_field() { local v="${1//\"/\"\"}"; printf '"%s"' "$v"; }

render_csv() {
    local pre="$timestamp_utc,$host_name"
    echo "timestamp_utc,host,section,item,count"
    local n_records="n/a"
    if [[ "$SOURCE" != "n/a" ]]; then n_records="$(grep -c . <<< "$records")"; fi
    printf '%s,summary,%s,%s\n' "$pre" "$(csv_field "source: $SOURCE")" "$n_records"
    local k
    for k in ssh_failed ssh_invalid ssh_maxauth ssh_accepted sudo_fail sudo_nots sudo_ok su_fail login_fail distinct_ips over_count saf_count; do
        printf '%s,summary,%s,%s\n' "$pre" "$k" "${!k}"
    done
    printf '%s,summary,threshold,%s\n' "$pre" "$THRESHOLD"
    while IFS=$'\t' read -r c m; do [[ -n "${c:-}" ]] && printf '%s,accepted_method,%s,%s\n' "$pre" "$(csv_field "$m")" "$c"; done <<< "$method_list"
    while IFS=$'\t' read -r c a ip _; do [[ -n "${c:-}" ]] && printf '%s,source_address,%s,%s\n' "$pre" "$(csv_field "$ip ($a accounts)")" "$c"; done <<< "$(head -n "$TOP" <<< "$ip_list")"
    while IFS=$'\t' read -r c u; do [[ -n "${c:-}" ]] && printf '%s,account,%s,%s\n' "$pre" "$(csv_field "$u")" "$c"; done <<< "$user_list"
    while IFS=$'\t' read -r t ip u m c; do [[ -n "${t:-}" ]] && printf '%s,success_after_failure,%s,%s\n' "$pre" "$(csv_field "$t $ip user=$u method=$m")" "$c"; done <<< "$saf_list"
}

if [[ "$FORMAT" == "csv" ]]; then report="$(render_csv)"; ext="csv"; else report="$(render_text)"; ext="txt"; fi
printf '%s\n' "$report"

if [[ -n "$OUTPUT_DIR" ]]; then
    out_file="$OUTPUT_DIR/failed-login-report-${host_name}-$(date -u +%Y%m%dT%H%M%SZ).$ext"
    printf '%s\n' "$report" > "$out_file" 2>/dev/null || die "cannot write report to '$out_file'" 2
    echo "Report saved to: $out_file" >&2
fi

exit $(( breach ? 3 : 0 ))

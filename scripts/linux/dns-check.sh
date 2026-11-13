#!/usr/bin/env bash
#
# dns-check.sh — Read-only forward and reverse DNS lookups across several resolvers.
#
# Course : Linux & PowerShell Professional Mastery (Day 13)
# Target : Ubuntu 24.04 LTS (works on any Linux with Bash 4+)
# Needs  : bash 4+, getent (glibc), awk, sort. Recommended: dig (package bind9-dnsutils /
#          dnsutils); without dig the script uses host, and without both it can only query
#          the system resolver (getent) and reports per-server lookups as n/a.
#          resolvectl (systemd-resolved) is used, when present, to discover upstream servers.
#          No root required.
#
# Usage  : ./dns-check.sh [-n NAME[,NAME...]] [-s SERVER[,SERVER...]] [-t TYPE[,TYPE...]]
#                         [-r] [-w SECONDS] [-f text|csv] [-o OUTPUT_DIR] [-h]
#   -n NAMES    Names to look up (comma list; option may be repeated). Default: example.com
#               on every resolver, plus this host's own name on the system resolver only
#   -s SERVERS  Resolvers to ask: IPv4/IPv6 addresses or the word "system" (glibc via getent,
#               which also reads /etc/hosts). Default: system + the servers in
#               /etc/resolv.conf + the upstream servers reported by resolvectl
#   -t TYPES    Record types: A AAAA CNAME MX NS TXT SOA SRV CAA PTR (default A,AAAA).
#               The system resolver answers only A and AAAA; other types show n/a there
#   -r          Reverse check: PTR for every address found, and whether the PTR name
#               resolves back to the same address (forward-confirmed reverse DNS)
#   -w SECONDS  Timeout per query, 1-30 (default 2). Each query is tried once
#   -f FMT      Output format: text (default) or csv
#   -o DIR      Also save the report to DIR/dns-check-<host>-<UTC timestamp>.<txt|csv>
#   -h          Show this help
#
# Exit codes: 0 OK · 1 invalid arguments · 2 output directory problem
#             3 at least one lookup failed (NXDOMAIN, SERVFAIL, REFUSED, TIMEOUT...),
#               resolvers disagree, or (with -r) a PTR is missing or does not match
#
# Safety: this script only sends DNS queries (dig/host/getent). It never changes resolver
#         configuration, caches or files (except the optional report in -o DIR).

set -o nounset
set -o pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly VALID_TYPES="A AAAA CNAME MX NS TXT SOA SRV CAA PTR"
NAMES=()
SERVERS=()
TYPES=()
REVERSE=0
TIMEOUT_S=2
FORMAT="text"
OUTPUT_DIR=""
DEFAULT_NAMES=1

usage() {
    sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'
}

die() {
    printf '%s: error: %s\n' "$SCRIPT_NAME" "$1" >&2
    exit "${2:-1}"
}

is_ipv4() {
    local ip="$1" o
    [[ "$ip" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]] || return 1
    for o in "${BASH_REMATCH[@]:1}"; do (( 10#$o <= 255 )) || return 1; done
}
is_ipv6() { [[ "$1" =~ ^[0-9A-Fa-f:.]+$ && "$1" == *:*:* ]]; }
is_name() {
    local n="${1%.}"
    (( ${#n} >= 1 && ${#n} <= 253 )) || return 1
    [[ "$n" =~ ^[A-Za-z0-9_]([A-Za-z0-9_-]{0,62})(\.[A-Za-z0-9_]([A-Za-z0-9_-]{0,62}))*$ ]]
}

# split_csv VALUE ARRAY_NAME — append comma-separated, non-empty items to the named array.
split_csv() {
    local item
    local -n _target="$2"
    IFS=',' read -r -a _items <<< "$1"
    for item in "${_items[@]}"; do
        item="${item//[[:space:]]/}"
        [[ -n "$item" ]] && _target+=("$item")
    done
}

# ---------- argument parsing ----------
while getopts ":n:s:t:rw:f:o:h" opt; do
    case "$opt" in
        n) split_csv "$OPTARG" NAMES; DEFAULT_NAMES=0 ;;
        s) split_csv "$OPTARG" SERVERS ;;
        t) split_csv "${OPTARG^^}" TYPES ;;
        r) REVERSE=1 ;;
        w) TIMEOUT_S="$OPTARG" ;;
        f) FORMAT="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        h) usage; exit 0 ;;
        :) die "option -$OPTARG requires an argument" ;;
        \?) die "unknown option -$OPTARG (use -h for help)" ;;
    esac
done
shift $((OPTIND - 1))
[[ $# -eq 0 ]] || die "unexpected argument '$1' (use -h for help)"

if ! [[ "$TIMEOUT_S" =~ ^[0-9]+$ ]] || (( 10#$TIMEOUT_S < 1 || 10#$TIMEOUT_S > 30 )); then
    die "-w must be an integer from 1 to 30"
fi
TIMEOUT_S=$((10#$TIMEOUT_S))
case "$FORMAT" in
    text|csv) ;;
    *) die "invalid format '$FORMAT' (expected text or csv)" ;;
esac
(( ${#NAMES[@]} <= 50 )) || die "at most 50 names can be checked in one run"
for n in "${NAMES[@]}"; do is_name "$n" || die "invalid DNS name '$n'"; done
[[ ${#TYPES[@]} -gt 0 ]] || TYPES=(A AAAA)
for t in "${TYPES[@]}"; do
    [[ " $VALID_TYPES " == *" $t "* ]] || die "unsupported record type '$t' (allowed: $VALID_TYPES)"
done
for s in "${SERVERS[@]}"; do
    [[ "$s" == "system" ]] || is_ipv4 "$s" || is_ipv6 "$s" \
        || die "invalid server '$s' (use an IPv4/IPv6 address or 'system')"
done

if [[ -n "$OUTPUT_DIR" ]]; then
    mkdir -p -- "$OUTPUT_DIR" 2>/dev/null || die "cannot create output directory '$OUTPUT_DIR'" 2
    [[ -w "$OUTPUT_DIR" ]] || die "output directory '$OUTPUT_DIR' is not writable" 2
fi

# ---------- tools ----------
TOOL="getent"
command -v host >/dev/null 2>&1 && TOOL="host"
command -v dig >/dev/null 2>&1 && TOOL="dig"
HAVE_GETENT=0; command -v getent >/dev/null 2>&1 && HAVE_GETENT=1
HAVE_TIMEOUT=0; command -v timeout >/dev/null 2>&1 && HAVE_TIMEOUT=1
tool_version="n/a"
case "$TOOL" in
    dig)  tool_version="$(dig -v 2>&1 | awk '{print $2; exit}')" ;;
    host) tool_version="dig not installed" ;;
    getent) tool_version="dig and host not installed; system resolver only" ;;
esac

# run_limited SECONDS CMD... — run a command with a hard time limit when timeout(1) exists.
run_limited() {
    local limit="$1"; shift
    if (( HAVE_TIMEOUT )); then timeout "$limit" "$@"; else "$@"; fi
}

# ---------- default servers and names ----------
add_server() {
    local s="$1" e
    for e in "${SERVERS[@]}"; do [[ "$e" == "$s" ]] && return 0; done
    SERVERS+=("$s")
}
if [[ ${#SERVERS[@]} -eq 0 ]]; then
    SERVERS=(system)
    if [[ -r /etc/resolv.conf ]]; then
        while read -r s; do
            { is_ipv4 "$s" || is_ipv6 "$s"; } && add_server "$s"
        done < <(awk '$1 == "nameserver" {print $2}' /etc/resolv.conf)
    fi
    if command -v resolvectl >/dev/null 2>&1; then
        # "resolvectl dns" prints "Global: 1.1.1.1" and "Link 2 (eth0): 192.168.1.1 fe80::1%2".
        while read -r s; do
            s="${s%%#*}"; s="${s%%%*}"
            { is_ipv4 "$s" || is_ipv6 "$s"; } && add_server "$s"
        done < <(run_limited 5 resolvectl dns 2>/dev/null | awk -F': ' 'NF > 1 {n = split($2, a, " "); for (i = 1; i <= n; i++) print a[i]}')
    fi
fi

# Each check is "name|scope" where scope "all" = every server and "system" = system only.
CHECKS=()
if (( DEFAULT_NAMES )); then
    CHECKS+=("example.com|all")
    own="$(hostname 2>/dev/null || true)"
    is_name "${own:-}" && CHECKS+=("$own|system")
else
    for n in "${NAMES[@]}"; do CHECKS+=("${n%.}|all"); done
fi

# ---------- query functions ----------
# Each sets: Q_STATUS Q_TTL Q_MS Q_ANS (space-separated, sorted answers of the requested type)
Q_STATUS=""; Q_TTL=""; Q_MS=""; Q_ANS=""

query_dig() {
    local server="$1" name="$2" type="$3" out rc
    local -a args=(+timeout="$TIMEOUT_S" +tries=1 +noall +comments +answer +stats)
    if [[ "$type" == "PTR" ]]; then args+=(-x "$name"); else args+=("$name" "$type"); fi
    out="$(run_limited $((TIMEOUT_S + 3)) dig "@$server" "${args[@]}" 2>&1)"; rc=$?
    Q_TTL="n/a"; Q_MS="n/a"; Q_ANS=""
    Q_STATUS="$(awk '/->>HEADER<<-/ {for (i = 1; i <= NF; i++) if ($i == "status:") {s = $(i + 1); sub(/,/, "", s); print s; exit}}' <<< "$out")"
    if [[ -z "$Q_STATUS" ]]; then
        case "$out" in
            *"timed out"*) Q_STATUS="TIMEOUT" ;;
            *"connection refused"*) Q_STATUS="CONN-REFUSED" ;;
            *"network unreachable"*|*"host unreachable"*) Q_STATUS="UNREACHABLE" ;;
            *) Q_STATUS="ERROR" ;;
        esac
        (( rc == 124 )) && Q_STATUS="TIMEOUT"
        return 0
    fi
    Q_MS="$(awk '/^;; Query time:/ {print $4; exit}' <<< "$out")"
    [[ -n "$Q_MS" ]] || Q_MS="n/a"
    # Answer lines: owner TTL class type data...
    Q_ANS="$(awk -v t="$type" '!/^;/ && NF >= 5 && $4 == t {d = $5; for (i = 6; i <= NF; i++) d = d " " $i; gsub(/ /, "_", d); print d}' <<< "$out" | sort -u | tr '\n' ' ')"
    Q_ANS="${Q_ANS% }"
    local ttl
    ttl="$(awk -v t="$type" '!/^;/ && NF >= 5 && $4 == t {print $2}' <<< "$out" | sort -n | head -n 1)"
    [[ -n "$ttl" ]] && Q_TTL="$ttl"
    [[ "$Q_STATUS" == "NOERROR" && -z "$Q_ANS" ]] && Q_STATUS="NODATA"
    [[ "$Q_STATUS" == "NOERROR" ]] && Q_STATUS="OK"
    return 0
}

query_host() {
    local server="$1" name="$2" type="$3" out
    local -a args=(-W "$TIMEOUT_S" -t "$type")
    out="$(run_limited $((TIMEOUT_S + 3)) host "${args[@]}" "$name" "$server" 2>&1)"
    Q_TTL="n/a"; Q_MS="n/a"; Q_ANS=""
    case "$out" in
        *"NXDOMAIN"*) Q_STATUS="NXDOMAIN"; return 0 ;;
        *"SERVFAIL"*) Q_STATUS="SERVFAIL"; return 0 ;;
        *"REFUSED"*) Q_STATUS="REFUSED"; return 0 ;;
        *"timed out"*|*"no servers could be reached"*) Q_STATUS="TIMEOUT"; return 0 ;;
        *"connection refused"*) Q_STATUS="CONN-REFUSED"; return 0 ;;
    esac
    Q_ANS="$(awk '/ has address | has IPv6 address | domain name pointer | is an alias for | mail is handled by | name server | descriptive text | has SRV record | has CAA record | has SOA record /' <<< "$out" \
        | sed -E 's/.* (has address|has IPv6 address|domain name pointer|is an alias for|mail is handled by|name server|descriptive text|has SRV record|has CAA record|has SOA record) //' \
        | tr ' ' '_' | sort -u | tr '\n' ' ')"
    Q_ANS="${Q_ANS% }"
    if [[ -n "$Q_ANS" ]]; then Q_STATUS="OK"; else Q_STATUS="NODATA"; fi
    return 0
}

query_system() {
    local name="$1" type="$2" out db
    Q_TTL="n/a"; Q_MS="n/a"; Q_ANS=""
    if (( ! HAVE_GETENT )); then Q_STATUS="n/a"; return 0; fi
    case "$type" in
        A) db="ahostsv4" ;;
        AAAA) db="ahostsv6" ;;
        PTR) db="hosts" ;;
        *) Q_STATUS="n/a"; return 0 ;;
    esac
    local start end
    start="$(date +%s%N 2>/dev/null || echo 0)"
    out="$(run_limited $((TIMEOUT_S * 3 + 2)) getent "$db" "$name" 2>/dev/null)"
    local rc=$?
    end="$(date +%s%N 2>/dev/null || echo 0)"
    [[ "$start" =~ ^[0-9]+$ && "$end" =~ ^[0-9]+$ && "$start" != 0 ]] && Q_MS=$(( (end - start) / 1000000 ))
    if (( rc == 124 )); then Q_STATUS="TIMEOUT"; return 0; fi
    if (( rc != 0 )) || [[ -z "$out" ]]; then Q_STATUS="NOTFOUND"; return 0; fi
    if [[ "$type" == "PTR" ]]; then
        Q_ANS="$(awk '{print $2 "."; exit}' <<< "$out")"
    else
        Q_ANS="$(awk '{print $1}' <<< "$out" | sort -u | tr '\n' ' ')"
        Q_ANS="${Q_ANS% }"
    fi
    Q_STATUS="OK"
}

lookup() {   # lookup SERVER NAME TYPE
    if [[ "$1" == "system" ]]; then query_system "$2" "$3"; return; fi
    case "$TOOL" in
        dig) query_dig "$@" ;;
        host) query_host "$@" ;;
        *) Q_STATUS="n/a"; Q_TTL="n/a"; Q_MS="n/a"; Q_ANS="" ;;
    esac
}

is_failure() {
    case "$1" in
        NXDOMAIN|SERVFAIL|REFUSED|TIMEOUT|CONN-REFUSED|UNREACHABLE|ERROR|FORMERR|NOTIMP) return 0 ;;
        *) return 1 ;;
    esac
}

# ---------- run the lookups ----------
RESULTS=()      # name|type|server|status|ttl|ms|answers
PROBLEMS=()
CONSIST=()      # name|type|SAME/DIFFER|detail
declare -A SYS_FOUND=() SYS_TRIED=()

for check in "${CHECKS[@]}"; do
    name="${check%|*}"; scope="${check#*|}"
    for type in "${TYPES[@]}"; do
        declare -A sigs=()
        for server in "${SERVERS[@]}"; do
            [[ "$scope" == "system" && "$server" != "system" ]] && continue
            lookup "$server" "$name" "$type"
            RESULTS+=("$name|$type|$server|$Q_STATUS|$Q_TTL|$Q_MS|${Q_ANS:--}")
            if is_failure "$Q_STATUS"; then
                PROBLEMS+=("LOOKUP    $name $type via $server: $Q_STATUS")
            fi
            if [[ "$server" == "system" && "$Q_STATUS" != "n/a" ]]; then
                SYS_TRIED[$name]=1
                [[ "$Q_STATUS" == "OK" ]] && SYS_FOUND[$name]=1
            fi
            # Compare answers between resolvers; failed lookups are already problems.
            # The system resolver takes part only for A (it may omit AAAA on IPv4-only hosts).
            if ! is_failure "$Q_STATUS" && [[ "$Q_STATUS" != "n/a" && "$Q_STATUS" != "NOTFOUND" ]] \
                && { [[ "$server" != "system" ]] || [[ "$type" == "A" ]]; }; then
                sigs[$server]="${Q_ANS:--}"
            fi
        done
        if (( ${#sigs[@]} > 1 )); then
            distinct="$(printf '%s\n' "${sigs[@]}" | sort -u | grep -c .)"
            if (( distinct > 1 )); then
                detail=""
                for server in "${!sigs[@]}"; do detail+="$server=${sigs[$server]}; "; done
                CONSIST+=("$name|$type|DIFFER|${detail%; }")
                PROBLEMS+=("DIFFER    $name $type: resolvers return different answers (${detail%; })")
            else
                CONSIST+=("$name|$type|SAME|${#sigs[@]} resolvers agree")
            fi
        fi
        unset sigs
    done
done
for name in "${!SYS_TRIED[@]}"; do
    [[ -n "${SYS_FOUND[$name]:-}" ]] || PROBLEMS+=("LOOKUP    $name: the system resolver (getent) found no address")
done

# ---------- reverse checks ----------
REVERSE_ROWS=()   # address|ptr|status|confirmed
if (( REVERSE )); then
    declare -A seen_addr=()
    rev_server=""
    for server in "${SERVERS[@]}"; do [[ "$server" != "system" ]] && { rev_server="$server"; break; }; done
    [[ -n "$rev_server" && "$TOOL" != "getent" ]] || rev_server="system"
    for row in "${RESULTS[@]}"; do
        IFS='|' read -r _ rtype _ _ _ _ rans <<< "$row"
        [[ "$rtype" == "A" || "$rtype" == "AAAA" ]] || continue
        for addr in $rans; do
            [[ "$addr" == "-" || -n "${seen_addr[$addr]:-}" ]] && continue
            seen_addr[$addr]=1
            lookup "$rev_server" "$addr" PTR
            ptr="${Q_ANS%% *}"; pstatus="$Q_STATUS"; confirmed="n/a"
            if [[ "$pstatus" == "OK" && -n "$ptr" ]]; then
                ftype="A"; [[ "$addr" == *:* ]] && ftype="AAAA"
                lookup "$rev_server" "${ptr%.}" "$ftype"
                if [[ " $Q_ANS " == *" $addr "* ]]; then confirmed="yes"; else confirmed="NO"; fi
                [[ "$confirmed" == "NO" ]] && PROBLEMS+=("PTR       $addr -> $ptr does not resolve back to $addr")
            else
                ptr="-"
                is_failure "$pstatus" || [[ "$pstatus" == "NODATA" || "$pstatus" == "NOTFOUND" ]] \
                    && PROBLEMS+=("PTR       $addr has no PTR record ($pstatus via $rev_server)")
            fi
            REVERSE_ROWS+=("$addr|$ptr|$pstatus|$confirmed|$rev_server")
        done
    done
fi

# ---------- report ----------
host_name="$(hostname 2>/dev/null || echo n/a)"
timestamp_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
status="OK"; (( ${#PROBLEMS[@]} > 0 )) && status="PROBLEMS FOUND"
server_list="${SERVERS[*]}"

render_text() {
    printf '==============================================\n DNS Check Report\n==============================================\n'
    printf '%-20s : %s\n' "Report time (UTC)" "$timestamp_utc" "Host name" "$host_name" \
        "Lookup tool" "$TOOL ($tool_version)" "Resolvers" "$server_list" \
        "Record types" "${TYPES[*]}" "Timeout" "${TIMEOUT_S}s per query, 1 try" \
        "Reverse check" "$( (( REVERSE )) && echo yes || echo no)" "Status" "$status"
    printf '\n--- Lookups ---\n'
    printf '%-28s %-5s %-16s %-12s %6s %6s  %s\n' NAME TYPE SERVER STATUS TTL MS ANSWERS
    local row n t s st ttl ms ans
    for row in "${RESULTS[@]}"; do
        IFS='|' read -r n t s st ttl ms ans <<< "$row"
        printf '%-28s %-5s %-16s %-12s %6s %6s  %s\n' "$n" "$t" "$s" "$st" "$ttl" "$ms" "${ans//_/ }"
    done
    if (( ${#CONSIST[@]} > 0 )); then
        printf '\n--- Resolver consistency ---\n'
        for row in "${CONSIST[@]}"; do
            IFS='|' read -r n t s ans <<< "$row"
            printf '%-7s %-28s %-5s %s\n' "$s" "$n" "$t" "${ans//_/ }"
        done
    fi
    if (( REVERSE )); then
        printf '\n--- Reverse (PTR) check ---\n'
        printf '%-40s %-34s %-10s %-9s %s\n' ADDRESS PTR STATUS CONFIRMED VIA
        if (( ${#REVERSE_ROWS[@]} == 0 )); then printf 'No addresses were found to check.\n'; fi
        for row in "${REVERSE_ROWS[@]}"; do
            IFS='|' read -r n t st ans s <<< "$row"
            printf '%-40s %-34s %-10s %-9s %s\n' "$n" "$t" "$st" "$ans" "$s"
        done
    fi
    printf '\n--- Problems ---\n'
    if (( ${#PROBLEMS[@]} == 0 )); then printf 'None.\n'; else printf '%s\n' "${PROBLEMS[@]//_/ }"; fi
}

csv_field() { local v="${1//\"/\"\"}"; printf '"%s"' "${v//_/ }"; }

render_csv() {
    printf 'section,name,type,server,status,ttl,ms,answers\n'
    local row n t s st ttl ms ans
    for row in "${RESULTS[@]}"; do
        IFS='|' read -r n t s st ttl ms ans <<< "$row"
        printf 'lookup,%s,%s,%s,%s,%s,%s,%s\n' "$n" "$t" "$s" "$st" "$ttl" "$ms" "$(csv_field "$ans")"
    done
    for row in "${CONSIST[@]}"; do
        IFS='|' read -r n t s ans <<< "$row"
        printf 'consistency,%s,%s,,%s,,,%s\n' "$n" "$t" "$s" "$(csv_field "$ans")"
    done
    for row in "${REVERSE_ROWS[@]}"; do
        IFS='|' read -r n t st ans s <<< "$row"
        printf 'reverse,%s,PTR,%s,%s,,,%s\n' "$n" "$s" "$st" "$(csv_field "$t confirmed=$ans")"
    done
}

if [[ "$FORMAT" == "csv" ]]; then report="$(render_csv)"; ext="csv"; else report="$(render_text)"; ext="txt"; fi
printf '%s\n' "$report"

if [[ -n "$OUTPUT_DIR" ]]; then
    file="$OUTPUT_DIR/dns-check-${host_name}-$(date -u +%Y%m%dT%H%M%SZ).$ext"
    printf '%s\n' "$report" > "$file" 2>/dev/null || die "cannot write report to '$file'" 2
    printf 'Report saved to %s\n' "$file" >&2
fi

(( ${#PROBLEMS[@]} == 0 )) || exit 3
exit 0

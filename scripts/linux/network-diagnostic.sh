#!/usr/bin/env bash
#
# network-diagnostic.sh — Read-only, layered network diagnosis of one interface:
#                         link -> addresses -> counters -> default route -> gateway
#                         -> DNS -> TCP port, with one OK/WARN/FAIL line per check.
#
# Course : Linux & PowerShell Professional Mastery (Day 15)
# Target : Ubuntu 24.04 LTS (works on any Linux with iproute2 'ip' and /sys/class/net)
# Needs  : bash 4+, iproute2 (ip), awk, timeout (coreutils). Optional: ethtool (speed/duplex
#          when /sys does not report it), ping (iputils-ping), getent (libc). No root required;
#          checks whose tool or permission is missing are reported as "n/a".
#
# Usage  : ./network-diagnostic.sh [-i IFACE] [-t HOST] [-p PORT] [-n DNSNAME] [-e MAXERR]
#                                  [-f text|csv] [-o OUTPUT_DIR] [-h]
#   -i IFACE      Interface to check (default: the interface of the IPv4 default route;
#                 if there is none, the first non-loopback interface that is UP)
#   -t HOST       Also test a TCP connection to HOST (name or IP address)
#   -p PORT       TCP port for -t (default 443)
#   -n DNSNAME    Also resolve DNSNAME through the system resolver (getent ahosts)
#   -e MAXERR     Maximum interface errors + drops before the counter check is flagged
#                 (default 0). Errors above the limit = FAIL; drops alone = WARN, because
#                 drops also count harmless discards (unknown protocols, filtered frames).
#   -f FMT        Output format: text (default) or csv
#   -o DIR        Also save the report to DIR/network-diagnostic-<host>-<UTC timestamp>.<ext>
#   -h            Show this help
#
# Exit codes: 0 OK (warnings allowed) · 1 invalid arguments · 2 output file problem
#             3 threshold breached: at least one check FAILED
#
# Safety: this script only READS interface state, counters, routes and the neighbour table,
#         and sends at most 2 pings to the gateway, one DNS lookup and one TCP connection
#         attempt. It never changes addresses, routes, links or firewall rules.

set -o nounset
set -o pipefail

readonly SCRIPT_NAME="${0##*/}"
IFACE=""
TARGET=""
PORT="443"
PORT_SET=0
DNSNAME=""
MAXERR="0"
FORMAT="text"
OUTPUT_DIR=""

usage() {
    sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'
}

die() {
    printf '%s: error: %s\n' "$SCRIPT_NAME" "$1" >&2
    exit "${2:-1}"
}

# ---------- argument parsing ----------
while getopts ":i:t:p:n:e:f:o:h" opt; do
    case "$opt" in
        i) IFACE="$OPTARG" ;;
        t) TARGET="$OPTARG" ;;
        p) PORT="$OPTARG"; PORT_SET=1 ;;
        n) DNSNAME="$OPTARG" ;;
        e) MAXERR="$OPTARG" ;;
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
if [[ ! "$PORT" =~ ^[0-9]{1,5}$ ]] || (( 10#$PORT < 1 || 10#$PORT > 65535 )); then
    die "-p must be a port number 1-65535"
fi
PORT=$((10#$PORT))
(( PORT_SET == 0 )) || [[ -n "$TARGET" ]] || die "-p needs -t HOST"
[[ "$MAXERR" =~ ^[0-9]{1,12}$ ]] || die "-e must be a non-negative whole number"
MAXERR=$((10#$MAXERR))
if [[ -n "$IFACE" ]]; then
    [[ "$IFACE" =~ ^[A-Za-z0-9._@:-]{1,15}$ ]] || die "invalid interface name '$IFACE'"
    [[ -e "/sys/class/net/$IFACE" ]] || die "interface '$IFACE' does not exist (see: ip -br link)"
fi
for v in "$TARGET" "$DNSNAME"; do
    [[ -z "$v" || "$v" =~ ^[A-Za-z0-9._:-]{1,253}$ ]] || die "invalid host or DNS name '$v'"
done
if [[ -n "$OUTPUT_DIR" ]]; then
    mkdir -p -- "$OUTPUT_DIR" 2>/dev/null || die "cannot create output directory '$OUTPUT_DIR'" 2
    [[ -d "$OUTPUT_DIR" && -w "$OUTPUT_DIR" ]] || die "output directory '$OUTPUT_DIR' is not writable" 2
fi

HAVE_IP=0
command -v ip >/dev/null 2>&1 && HAVE_IP=1

# ---------- results ----------
# Each check appends "CHECK<TAB>STATUS<TAB>DETAIL".
results=""
fail_count=0
warn_count=0
add() {
    results+="$1"$'\t'"$2"$'\t'"$3"$'\n'
    [[ "$2" == "FAIL" ]] && fail_count=$((fail_count + 1))
    [[ "$2" == "WARN" ]] && warn_count=$((warn_count + 1))
    return 0
}

sysval() {
    # Prints a /sys/class/net value, or "n/a" when it cannot be read (e.g. carrier on a down link).
    local v
    v="$(cat "/sys/class/net/$IFACE/$1" 2>/dev/null)" || v=""
    echo "${v:-n/a}"
}

# ---------- choose the interface ----------
DEF_GW=""
DEF_DEV=""
if (( HAVE_IP )); then
    read -r DEF_GW DEF_DEV < <(LC_ALL=C ip -4 route show default 2>/dev/null | awk '
        { gw = "-"; dev = ""
          for (i = 1; i < NF; i++) { if ($i == "via") gw = $(i + 1); if ($i == "dev") dev = $(i + 1) }
          if (dev != "") { print gw, dev; exit } }')
fi
[[ "$DEF_GW" == "-" ]] && DEF_GW=""
IFACE_SOURCE="-i"
if [[ -z "$IFACE" ]]; then
    if [[ -n "$DEF_DEV" ]]; then
        IFACE="$DEF_DEV"; IFACE_SOURCE="default route"
    else
        for d in /sys/class/net/*; do
            n="${d##*/}"
            [[ "$n" == "lo" || ! -e "$d" ]] && continue
            if [[ "$(cat "$d/operstate" 2>/dev/null)" == "up" ]]; then IFACE="$n"; IFACE_SOURCE="first UP interface (no default route)"; break; fi
        done
    fi
fi

host_name="$(hostname 2>/dev/null || echo n/a)"
timestamp_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ---------- layer 1/2: link ----------
if [[ -z "$IFACE" ]]; then
    add "interface" "FAIL" "no default route and no non-loopback interface is UP (see: ip -br link)"
    IFACE="n/a"; IFACE_SOURCE="none found"
else
    oper="$(sysval operstate)"
    flags="$(sysval flags)"
    admin="down"
    if [[ "$flags" =~ ^0x[0-9a-fA-F]+$ ]] && (( flags & 1 )); then admin="up"; fi
    case "$oper" in
        up)      add "link-state" "OK"   "admin $admin, operstate up" ;;
        unknown) if [[ "$admin" == "up" ]]; then add "link-state" "WARN" "admin up, operstate unknown (normal for some virtual/tunnel interfaces)"
                 else add "link-state" "FAIL" "admin down, operstate unknown (fix: sudo ip link set $IFACE up)"; fi ;;
        dormant) add "link-state" "WARN" "admin $admin, operstate dormant (waiting for 802.1X/Wi-Fi authentication?)" ;;
        *)       if [[ "$admin" == "down" ]]; then add "link-state" "FAIL" "admin down, operstate $oper (fix: sudo ip link set $IFACE up)"
                 else add "link-state" "FAIL" "admin up, operstate $oper (no link: cable, switch port, peer or driver)"; fi ;;
    esac

    carrier="$(sysval carrier)"
    case "$carrier" in
        1)   add "carrier" "OK" "carrier detected" ;;
        0)   add "carrier" "FAIL" "no carrier (cable unplugged, switch port down, or peer interface down)" ;;
        *)   add "carrier" "n/a" "not readable while the interface is administratively down" ;;
    esac

    mtu="$(sysval mtu)"
    mac="$(sysval address)"
    if [[ "$mtu" =~ ^[0-9]+$ ]] && (( mtu < 1280 )); then
        add "mtu-mac" "WARN" "MTU $mtu (below 1280: IPv6 will not work), MAC $mac"
    else
        add "mtu-mac" "OK" "MTU $mtu, MAC $mac"
    fi

    speed="$(sysval speed)"
    duplex="$(sysval duplex)"
    if [[ ! "$speed" =~ ^[0-9]+$ ]] && command -v ethtool >/dev/null 2>&1; then
        es="$(LC_ALL=C ethtool "$IFACE" 2>/dev/null | awk -F': ' '/^[[:space:]]*Speed:/ { print $2 }')"
        ed="$(LC_ALL=C ethtool "$IFACE" 2>/dev/null | awk -F': ' '/^[[:space:]]*Duplex:/ { print tolower($2) }')"
        [[ "$es" =~ ^([0-9]+)Mb/s$ ]] && speed="${BASH_REMATCH[1]}"
        [[ -n "$ed" ]] && duplex="$ed"
    fi
    if [[ "$oper" != "up" ]]; then
        add "speed-duplex" "n/a" "not meaningful while the link is $oper"
    elif [[ "$speed" =~ ^[0-9]+$ ]]; then
        if [[ "$duplex" == "half" ]]; then
            add "speed-duplex" "WARN" "${speed} Mb/s, half duplex (duplex mismatch? check the switch port)"
        else
            add "speed-duplex" "OK" "${speed} Mb/s, duplex $duplex"
        fi
    else
        add "speed-duplex" "n/a" "not reported by the driver (virtual NIC, Wi-Fi or link down)"
    fi

    # ---------- layer 3: addresses ----------
    if (( HAVE_IP )); then
        v4="$(LC_ALL=C ip -4 -o addr show dev "$IFACE" 2>/dev/null | awk '{ printf "%s%s", sep, $4; sep = " " }')"
        v6="$(LC_ALL=C ip -6 -o addr show dev "$IFACE" scope global 2>/dev/null | awk '{ printf "%s%s", sep, $4; sep = " " }')"
        if [[ -z "$v4" && -z "$v6" ]]; then
            add "addresses" "FAIL" "no IPv4 and no global IPv6 address (DHCP failed or not configured)"
        elif [[ -n "$v4" ]] && ! grep -qv '^169\.254\.' < <(tr ' ' '\n' <<< "$v4"); then
            add "addresses" "FAIL" "only link-local $v4 (169.254.x.x = no DHCP answer)"
        else
            add "addresses" "OK" "IPv4 ${v4:-none}; IPv6 global ${v6:-none}"
        fi
    else
        add "addresses" "n/a" "'ip' (iproute2) not installed"
    fi

    # ---------- counters ----------
    if [[ -r "/sys/class/net/$IFACE/statistics/rx_errors" ]]; then
        st() { local v; v="$(cat "/sys/class/net/$IFACE/statistics/$1" 2>/dev/null)"; echo "${v:-0}"; }
        rxe="$(st rx_errors)"; txe="$(st tx_errors)"; rxd="$(st rx_dropped)"; txd="$(st tx_dropped)"
        crc="$(st rx_crc_errors)"; frm="$(st rx_frame_errors)"; col="$(st collisions)"
        errs=$((rxe + txe)); drops=$((rxd + txd))
        detail="rx_errors $rxe, tx_errors $txe, rx_dropped $rxd, tx_dropped $txd"
        (( crc + frm + col > 0 )) && detail+=", crc $crc, frame $frm, collisions $col"
        detail+=" (since the interface came up; limit $MAXERR)"
        if (( errs > MAXERR )); then
            add "counters" "FAIL" "$detail"
        elif (( errs + drops > MAXERR )); then
            add "counters" "WARN" "$detail"
        else
            add "counters" "OK" "$detail"
        fi
    else
        add "counters" "n/a" "/sys/class/net/$IFACE/statistics not readable"
    fi
fi

# ---------- layer 3: default route and gateway ----------
if (( ! HAVE_IP )); then
    add "default-route" "n/a" "'ip' (iproute2) not installed"
elif [[ -z "$DEF_DEV" ]]; then
    add "default-route" "FAIL" "no IPv4 default route (only local subnets are reachable)"
else
    if [[ "$DEF_DEV" != "$IFACE" ]]; then
        add "default-route" "WARN" "default route uses $DEF_DEV, not $IFACE (via ${DEF_GW:-direct})"
    else
        add "default-route" "OK" "via ${DEF_GW:-direct (no gateway)} dev $DEF_DEV"
    fi
fi

if [[ -n "$DEF_GW" ]]; then
    ping_status="n/a"; ping_detail="ping not installed (sudo apt install iputils-ping)"
    if command -v ping >/dev/null 2>&1; then
        pout="$(LC_ALL=C timeout 6 ping -n -c 2 -W 1 "$DEF_GW" 2>&1)"; prc=$?
        if (( prc == 0 )); then
            ping_status="OK"; ping_detail="$(awk -F'= ' '/^rtt|^round-trip/ { split($2, r, "/"); print "2 pings, avg rtt " r[2] " ms" }' <<< "$pout")"
            [[ -n "$ping_detail" ]] || ping_detail="reply received"
        elif grep -qiE 'not permitted|permission denied' <<< "$pout"; then
            ping_status="n/a"; ping_detail="ICMP not permitted for this user"
        else
            ping_status="FAIL"; ping_detail="no reply from $DEF_GW"
        fi
    fi
    # Read the neighbour entry AFTER the ping, which refreshes it.
    neigh="$(LC_ALL=C ip neigh show "$DEF_GW" dev "$DEF_DEV" 2>/dev/null | awk 'NF { print; exit }')"
    nstate="$(awk '{ print $NF }' <<< "$neigh")"
    nmac="$(awk '{ for (i = 1; i < NF; i++) if ($i == "lladdr") print $(i + 1) }' <<< "$neigh")"
    case "$nstate" in
        REACHABLE|STALE|DELAY|PROBE|PERMANENT|NOARP)
            add "gateway-neighbour" "OK" "$DEF_GW is $nstate (lladdr ${nmac:-n/a})" ;;
        FAILED|INCOMPLETE)
            add "gateway-neighbour" "FAIL" "$DEF_GW is $nstate: no ARP/ND reply (wrong gateway, VLAN or link problem)" ;;
        *)
            add "gateway-neighbour" "WARN" "no neighbour entry for $DEF_GW on $DEF_DEV" ;;
    esac
    # A gateway may drop ICMP on purpose: if layer 2 works, a failed ping is only a warning.
    if [[ "$ping_status" == "FAIL" && "$nstate" =~ ^(REACHABLE|STALE|DELAY|PROBE|PERMANENT)$ ]]; then
        ping_status="WARN"; ping_detail+=" (but ARP works: ICMP may be filtered)"
    fi
    add "gateway-ping" "$ping_status" "$ping_detail"
elif [[ -n "$DEF_DEV" ]]; then
    add "gateway-ping" "n/a" "default route has no gateway (point-to-point or direct route)"
fi

# ---------- DNS ----------
if [[ -r /etc/resolv.conf ]]; then
    ns="$(awk '$1 == "nameserver" { printf "%s%s", sep, $2; sep = " " }' /etc/resolv.conf)"
    if [[ -n "$ns" ]]; then add "dns-config" "OK" "nameserver(s) in /etc/resolv.conf: $ns"
    else add "dns-config" "WARN" "no nameserver line in /etc/resolv.conf"; fi
else
    add "dns-config" "WARN" "/etc/resolv.conf missing or unreadable"
fi
if [[ -n "$DNSNAME" ]]; then
    if command -v getent >/dev/null 2>&1; then
        addrs="$(timeout 10 getent ahosts "$DNSNAME" 2>/dev/null | awk '{ print $1 }' | sort -u | head -4 | tr '\n' ' ')"
        if [[ -n "$addrs" ]]; then add "dns-lookup" "OK" "$DNSNAME -> ${addrs% }"
        else add "dns-lookup" "FAIL" "$DNSNAME did not resolve (getent ahosts; try: dig $DNSNAME)"; fi
    else
        add "dns-lookup" "n/a" "getent not available"
    fi
fi

# ---------- TCP port ----------
if [[ -n "$TARGET" ]]; then
    start_ns="$(date +%s%N)"
    # The single quotes are intended: $1 and $2 expand inside the child bash.
    # shellcheck disable=SC2016
    terr="$(timeout 5 bash -c 'exec 3<>"/dev/tcp/$1/$2"' _ "$TARGET" "$PORT" 2>&1)"; trc=$?
    ms=$(( ($(date +%s%N) - start_ns) / 1000000 ))
    if (( trc == 0 )); then
        add "tcp-connect" "OK" "$TARGET:$PORT open (${ms} ms)"
    elif (( trc == 124 )); then
        add "tcp-connect" "FAIL" "$TARGET:$PORT timed out after 5 s (filtered by a firewall, or no route)"
    elif grep -qi 'refused' <<< "$terr"; then
        add "tcp-connect" "FAIL" "$TARGET:$PORT connection refused (host reachable, nothing listening)"
    elif grep -qi 'no route to host' <<< "$terr"; then
        add "tcp-connect" "FAIL" "$TARGET:$PORT no route to host (no ARP reply or ICMP host unreachable: host down or wrong address)"
    elif grep -qiE 'unreachable' <<< "$terr"; then
        add "tcp-connect" "FAIL" "$TARGET:$PORT network/host unreachable"
    elif grep -qiE 'name or service|unknown host|resolv' <<< "$terr"; then
        add "tcp-connect" "FAIL" "$TARGET could not be resolved"
    else
        add "tcp-connect" "FAIL" "$TARGET:$PORT failed: $(tr -d '\n' <<< "${terr##*: }")"
    fi
fi

status="OK"
(( warn_count > 0 )) && status="WARN"
(( fail_count > 0 )) && status="FAIL"

# ---------- report ----------
render_text() {
    echo "=============================================="
    echo " Network Diagnostic Report"
    echo "=============================================="
    printf '%-20s : %s\n' "Report time (UTC)" "$timestamp_utc"
    printf '%-20s : %s\n' "Host name" "$host_name"
    printf '%-20s : %s\n' "Interface" "$IFACE ($IFACE_SOURCE)"
    printf '%-20s : %s\n' "Error limit (-e)" "$MAXERR"
    printf '%-20s : %s (%s failed, %s warnings)\n' "Status" "$status" "$fail_count" "$warn_count"
    echo
    echo "--- Checks (bottom-up: link -> IP -> gateway -> DNS -> port) ---"
    printf '%-18s %-5s %s\n' CHECK STATUS DETAIL
    while IFS=$'\t' read -r c s d; do
        [[ -n "${c:-}" ]] || continue
        printf '%-18s %-5s %s\n' "$c" "$s" "$d"
    done <<< "$results"
}

render_csv() {
    echo "timestamp_utc,host,interface,check,status,detail"
    while IFS=$'\t' read -r c s d; do
        [[ -n "${c:-}" ]] || continue
        printf '%s,%s,%s,%s,%s,"%s"\n' "$timestamp_utc" "$host_name" "$IFACE" "$c" "$s" "${d//\"/\"\"}"
    done <<< "$results"
}

if [[ "$FORMAT" == "csv" ]]; then report="$(render_csv)"; ext="csv"; else report="$(render_text)"; ext="txt"; fi
printf '%s\n' "$report"

if [[ -n "$OUTPUT_DIR" ]]; then
    out_file="$OUTPUT_DIR/network-diagnostic-${host_name}-$(date -u +%Y%m%dT%H%M%SZ).$ext"
    printf '%s\n' "$report" > "$out_file" 2>/dev/null || die "cannot write report to '$out_file'" 2
    echo "Report saved to: $out_file" >&2
fi

exit $(( fail_count > 0 ? 3 : 0 ))

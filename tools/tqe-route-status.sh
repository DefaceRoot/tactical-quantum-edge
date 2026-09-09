#!/bin/sh
# Read-only peer/target IPv4 route status for GUI display (OpenWrt + jshn).

set -e

JSHN=/usr/share/libubox/jshn.sh

usage() {
	echo "usage: $0 <peerIPv4> <primaryDevice> <backupDevice> <protectedDevice> <probeTargetIPv4>" >&2
	exit 1
}

is_ipv4_arg() {
	case "$1" in
	''|*[!0-9.]*) return 1 ;;
	esac
	return 0
}

is_dev_arg() {
	case "$1" in
	''|*[!A-Za-z0-9_.:-]*) return 1 ;;
	esac
	return 0
}

# Parse ip -4 route get → ROUTE_DEV/SRC/VIA (set -f + shift).
parse_route() {
	ROUTE_DEV=
	ROUTE_SRC=
	ROUTE_VIA=

	_out=$(ip -4 route get "$1" 2>/dev/null) || return 1
	[ -n "$_out" ] || return 1

	set -f
	set -- $_out
	set +f

	while [ $# -gt 0 ]; do
		case "$1" in
		dev)
			shift
			[ $# -gt 0 ] || break
			ROUTE_DEV=$1
			;;
		src)
			shift
			[ $# -gt 0 ] || break
			ROUTE_SRC=$1
			;;
		via)
			shift
			[ $# -gt 0 ] || break
			ROUTE_VIA=$1
			;;
		esac
		[ $# -gt 0 ] || break
		shift
	done

	[ -n "$ROUTE_DEV" ] || return 1
	return 0
}

unset SSH_ORIGINAL_COMMAND 2>/dev/null || true

[ "$#" -eq 5 ] || usage

PEER=$1
PRIMARY=$2
BACKUP=$3
PROTECTED=$4
TARGET=$5

is_ipv4_arg "$PEER" || usage
is_ipv4_arg "$TARGET" || usage
is_dev_arg "$PRIMARY" || usage
is_dev_arg "$BACKUP" || usage
is_dev_arg "$PROTECTED" || usage

[ -r "$JSHN" ] || {
	echo "missing jshn: $JSHN" >&2
	exit 1
}
. "$JSHN"

ACTIVE=unknown
IFACE=
SRC=
GW=
PROTECTED_ROUTE=0

if parse_route "$PEER"; then
	IFACE=$ROUTE_DEV
	SRC=$ROUTE_SRC
	GW=$ROUTE_VIA
	if [ "$ROUTE_DEV" = "$PRIMARY" ]; then
		ACTIVE=primary
	elif [ "$ROUTE_DEV" = "$BACKUP" ]; then
		ACTIVE=backup
	else
		ACTIVE=unknown
	fi
fi

if parse_route "$TARGET"; then
	if [ "$ROUTE_DEV" = "$PROTECTED" ]; then
		PROTECTED_ROUTE=1
	fi
fi

OBSERVED=$(date -u +%Y-%m-%dT%H:%M:%SZ)

json_init
json_add_string "active" "$ACTIVE"
json_add_string "interface" "$IFACE"
json_add_string "source_ip" "$SRC"
json_add_string "gateway" "$GW"
json_add_boolean "protected_route" "$PROTECTED_ROUTE"
json_add_string "observed_at" "$OBSERVED"
json_dump

exit 0

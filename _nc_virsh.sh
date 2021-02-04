#!/bin/bash

set -eou pipefail

fatal() {
  local rc=$1
  local msg=$2
  shift 2

  printf "ERROR: $msg\n" "$@" >&2
  exit $rc
}

if [[ $# -ne 3 ]]; then
  fatal 1 'Expected arguments [domain] [host] [port].
Note: This script is intended to be invoked by ssh, not run manually.'
fi

DOMAIN="$1"
LOOKUPHOST="$2"
LOOKUPPORT="$3"

# Remove the domain suffix from the hostname
sans_domain=$(sed "s/\\.${DOMAIN}\$//" <<< "$LOOKUPHOST")

if ! res=$(virsh domifaddr "$sans_domain"); then
  fatal 2 'could not look up libvirt domain %s.
Available libvirt domains: \n%s\n' "$sans_domain" "$(virsh list --name)"
fi

# Parse the IP address from the libvirt output
if ! ip=$(awk '$3 == "ipv4" { gsub("/.*", "", $4);
    print($4); exit(0); }' <<< "$res") || [[ -z "$ip" ]]; then
  fatal 3 'could not locate IP address for "%s"\n' "$sans_domain"
fi

printf 'translating "%s" --> %s\n' "$sans_domain" "$ip" >&2

exec nc "$ip" "$LOOKUPPORT"

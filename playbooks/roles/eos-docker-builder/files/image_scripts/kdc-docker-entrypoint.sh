#!/usr/local/bin/dumb-init /bin/sh
# shellcheck shell=bash
set -e

if [ -e /var/run/kdc.pid ] && ps "$(cat /var/run/kdc.pid)" | grep kdc &> /dev/null ; then
  echo "Already started, PID: $(cat /var/run/kdc.pid)"
  exit 1
fi

if [ "${1}" = '' ]; then
  set -- /usr/libexec/kdc
elif [ "${1:0:1}" = '-' ]; then
  # pass args to kdc
  set -- /usr/libexec/kdc "$@"
fi

echo -n "Starting kdc... "
exec "$@"

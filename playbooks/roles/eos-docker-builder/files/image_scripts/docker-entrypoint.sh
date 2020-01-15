#!/usr/local/bin/dumb-init /bin/bash
# shellcheck shell=bash

set -o xtrace

usage()
{
  echo "Usage:"
  echo "$(basename $0) qdb [-i <clusterID>] [-n <nodes>]"
  echo "$(basename $0) proxy"
  echo "$(basename $0) mq"
  echo "$(basename $0) mgm"
  echo "$(basename $0) fst [-g geotag]"
  echo
}

XROOTD_LOG_EXTRA_OPTION=( '' )


check_eos_daemon()
{
  [ -e "/tmp/$1/xrootd.pid" ] && ps "$(cat "/tmp/$1/xrootd.pid")" | grep "xrootd -n $1" &>/dev/null
}

check_eos_initialized()
{
  [ -e "/root/INITIALIZED_$1" ]
}

set_eos_initialized()
{
  touch "/root/INITIALIZED_$1"
}

run_qdb()
{
  if ! check_eos_daemon qdb ; then

    DB_PATH=( --path "$(grep 'redis\.database' /etc/xrd.cf.quarkdb | cut -d ' ' -f 2)" )
    CLUSTER_ID=( )
    NODES=( )

    while getopts 'i:n:' flag; do
      case "${flag}" in
        i) CLUSTER_ID=( --clusterID "${OPTARG}" ) ;;
        n) NODES=( --nodes "${OPTARG}" ) ;;
        *) usage
              exit 1;;
      esac
    done

    if ! check_eos_initialized qdb ; then
      quarkdb-create "${DB_PATH[@]}" "${CLUSTER_ID[@]}" "${NODES[@]}"
      chown -R daemon:daemon "${DB_PATH[1]}"

      set_eos_initialized qdb
    fi

    RUN_EOS_CMD=( "${XROOTDEXE}" -n qdb -c /etc/xrd.cf.quarkdb -l /var/log/eos/xrootd.qdb.log "${XROOTD_LOG_EXTRA_OPTION[@]}" -s /tmp/xrootd.qdb.pid -Rdaemon )
  else
    echo "Already started, PID: $(cat /tmp/qdb/xrootd.pid)"
    exit 1
  fi
}

run_proxy()
{
  if ! check_eos_daemon proxy ; then

    RUN_EOS_CMD=( "${XROOTDEXE}" -n proxy -c /etc/xrootd/xrootd-fwd-proxy.cfg -l /var/log/eos/xrootd.proxy.log "${XROOTD_LOG_EXTRA_OPTION[@]}" -s /tmp/xrootd.proxy.pid -Rdaemon )
  else
    echo "Already started, PID: $(cat /tmp/proxy/xrootd.pid)"
    exit 1
  fi
}

run_mq()
{
  if ! check_eos_daemon mq ; then
    if [ "${EOS_MGM_MASTER1}" == "${NODE_FQDN}" ] ; then
      if [[ "$XRD_ROLES" == *"mq"* ]]; then
        touch /var/eos/eos.mq.master
      fi
    else
      if [[ "$XRD_ROLES" == *"mq"* ]] && [ -e /var/eos/eos.mq.master ]; then
        unlink /var/eos/eos.mq.master
      fi
    fi

    RUN_EOS_CMD=( "${XROOTDEXE}" -n mq -c /etc/xrd.cf.mq -l /var/log/eos/xrootd.mq.log "${XROOTD_LOG_EXTRA_OPTION[@]}" -s /tmp/xrootd.mq.pid -Rdaemon )
  else
    echo "Already started, PID: $(cat /tmp/mq/xrootd.pid)"
    exit 1
  fi
}

run_mgm()
{
  if [[ "$XRD_ROLES" == *"mq"* ]]; then
    run_mq
    (cd /var/spool/eos/core && "${RUN_EOS_CMD[@]}" &)
    for count in {1..10}; do
      if check_eos_daemon mq ; then
        break
      fi
      sleep $count
    done

    sleep $count
    if ! check_eos_daemon mq ; then
      exit 1
    fi
    HAS_SUB_PROCESS=1
    RUN_EOS_CMD=( '' )
  fi

  if ! check_eos_daemon mgm ; then

    chown daemon:daemon /etc/eos.krb5.keytab

    if [ "${EOS_MGM_MASTER1}" == "${NODE_FQDN}" ] ; then
      if [[ "$XRD_ROLES" == *"mgm"* ]]; then
        touch /var/eos/eos.mgm.rw
      fi
    else
      if [[ "$XRD_ROLES" == *"mgm"* ]]  && [ -e /var/eos/eos.mgm.rw ]; then
        unlink /var/eos/eos.mgm.rw
      fi
    fi

    # TODO: What is -m flag?
    # TODO: setup logrotate
    RUN_EOS_CMD=( "${XROOTDEXE}" -n mgm -c /etc/xrd.cf.mgm -m -l /var/log/eos/xrootd.mgm.log "${XROOTD_LOG_EXTRA_OPTION[@]}" -s /tmp/xrootd.mgm.pid -Rdaemon)

  else
    echo "Already started, PID: $(cat /tmp/mgm/xrootd.pid)"
    exit 1
  fi
}

run_fst()
{
  if ! check_eos_daemon fst ; then
    GEOTAG=""

    while getopts 'g:' flag; do
      case "${flag}" in
        g) GEOTAG="${OPTARG}" ;;
        *) usage
              exit 1;;
      esac
    done

    # If specified, set new geotag instead of default one for FST server
    [[ -n $GEOTAG ]] && export EOS_GEOTAG=$GEOTAG

    RUN_EOS_CMD=( "${XROOTDEXE}" -n fst -c /etc/xrd.cf.fst -l /var/log/eos/xrootd.fst.log "${XROOTD_LOG_EXTRA_OPTION[@]}" -s /tmp/xrootd.fst.pid -Rdaemon )
  else
    echo "Already started, PID: $(cat /tmp/fst/xrootd.pid)"
    exit 1
  fi
}


if [ -e /etc/sysconfig/eos ]; then
  # shellcheck disable=SC1091
  source /etc/sysconfig/eos
fi

export EOS_MGM_URL="root://${EOS_MGM_ALIAS}:1094"

if [ -e /opt/eos/xrootd/bin/xrootd ]; then
  XROOTDEXE="/opt/eos/xrootd//bin/xrootd"
else
  XROOTDEXE="/usr/bin/xrootd"
fi

if [[ ! -v NODE_FQDN ]] ; then
  NODE_FQDN="$(hostname -f)"
fi

RUN_EOS_CMD=( '' )
HAS_SUB_PROCESS=0

ROLE=$1
shift

set -o pipefail
set -o errtrace
set -o nounset
set -o errexit

case "${ROLE}" in
  qdb)
    run_qdb "$@"
    ;;
  proxy)
    run_proxy "$@"
    ;;
  mq)
    run_mq "$@"
    ;;
  mgm)
    run_mgm "$@"
    ;;
  fst)
    run_fst "$@"
    ;;
  *)
    usage
    exit 1
esac

echo "Starting ${ROLE} for $(rpm -q eos-server | sed s/eos-server-//g)"
if [ $HAS_SUB_PROCESS -eq 1 ] ; then
  echo RUN
  cd /var/spool/eos/core && "${RUN_EOS_CMD[@]}"
else
  echo EXEC
  cd /var/spool/eos/core && exec "${RUN_EOS_CMD[@]}"
fi

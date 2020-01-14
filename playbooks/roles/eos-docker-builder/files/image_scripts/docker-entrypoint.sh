#!/usr/bin/env bash

set -o xtrace

usage()
{
  echo "Usage:"
  echo "$(basename $0) qdb [-i <clusterID>] [-n <nodes>]"
  echo "$(basename $0) proxy"
  echo "$(basename $0) mq"
  echo "$(basename $0) mgm"
  echo "$(basename $0) fst <fsid> [-u <uuid>] [-d <mountpoint>] [-s <space>] [-c <config_status>] [-g geotag]"
  echo
}

XROOTD_LOG_EXTRA_OPTION=( '' )

# full directory name of the script no matter where it is being called from
get_script_path() {
  if [[ -z "${SELF_PATH}" ]]; then
    # for non-symlink location
    #SELF_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
    # for any location
    source_path="${BASH_SOURCE[0]}"
    while [ -L "${source_path}" ]; do
      physical_directory="$(cd -P "$(dirname "${source_path}")" >/dev/null 2>&1 && pwd)"
      source_path="$(readlink "${source_path}")"
      [[ ${source_path} != /* ]] && source_path="${physical_directory}/${source_path}"
    done
    SELF_PATH="$(cd -P "$(dirname "${source_path}")" >/dev/null 2>&1 && pwd)"
  fi
  echo "${SELF_PATH}"
}
SELF_PATH="$(get_script_path)"
SELF="${SELF_PATH}/$(basename "${BASH_SOURCE[0]}")"


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

post_setup_qdb()
{
  if check_eos_initialized mq ; then
    set_eos_initialized mq
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

post_setup_proxy()
{
  if check_eos_initialized proxy ; then
    set_eos_initialized proxy
  fi
}

run_mq()
{
  if ! check_eos_daemon mq ; then
    if [ "${EOS_MGM_MASTER1}" == "$(hostname -f)" ] ; then
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

post_setup_mq()
{
  if check_eos_initialized mq ; then
    set_eos_initialized mq
  fi
}

run_mgm()
{
  if [[ "$XRD_ROLES" == *"mq"* ]]; then
    ${SELF} mq &
    for count in {1..10}; do
      if check_eos_daemon mq ; then
        break
      fi
      sleep 1
    done

    sleep 1
    if ! check_eos_daemon mq ; then
      exit 1
    fi
  fi

  if ! check_eos_daemon mgm ; then

    chown daemon:daemon /etc/eos.krb5.keytab

    if [ "${EOS_MGM_MASTER1}" == "$(hostname -f)" ] ; then
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

post_setup_mgm()
{
  if check_eos_initialized mgm ; then
    useradd eos-admin

    if [ "${EOS_MGM_MASTER1}" == "$(hostname -f)" ] ; then
      # Enable sss authentication for the FSTs to connect to the MGM
      eos -b vid enable sss
      #may be delete
      eos -b vid enable krb5

      # Make instance root directory world accessible
      eos -b chmod 2777 "/eos/${EOS_INSTANCE_NAME}/"

      # let the force be with eos-admin (typically krb-authenticated on clients)
      eos -b vid set membership eos-admin +sudo
    fi

    set_eos_initialized mgm
  fi
}


run_fst()
{
  if ! check_eos_daemon fst ; then
    export FSID=$1
    shift

    if [[ -z $FSID ]]; then
      echo -e "Filesystem ID (fsid) must be specified.\n"
      usage
      exit 1
    fi

    export UUID=fst${FSID}
    export DATADIR=/home/data/eos${FSID}
    export SPACE=default
    export CONFIG=rw
    export GEOTAG=""
     FSTHOSTNAME="$(hostname -f)"
    export FSTHOSTNAME

    while getopts 'u:d:s:c:g:' flag; do
      case "${flag}" in
        u) UUID="${OPTARG}" ;;
        d) DATADIR="${OPTARG}" ;;
        s) SPACE="${OPTARG}" ;;
        c) CONFIG="${OPTARG}" ;;
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

post_setup_fst()
{
  if check_eos_initialized fst${FSID} ; then
    echo "Configuration start for fst ${FSID} ..."
    mkdir -p $DATADIR
    echo "$UUID" > $DATADIR/.eosfsuuid
    echo "${FSID}" > $DATADIR/.eosfsid
    chown -R daemon:daemon $DATADIR
    # Give some time to the FST to start and then register with the MGM
    sleep 1
    eos -b fs add -m ${FSID} $UUID $FSTHOSTNAME:1095 $DATADIR $SPACE $CONFIG
    eos -b node set $FSTHOSTNAME:1095 on
    echo "Configuration done for fst ${FSID}"

    set_eos_initialized fst${FSID}
  fi
}


launch_post_setup_script()
{
  # shellcheck disable=SC2034
  for count in {1..100}; do
    if check_eos_daemon "$1" ; then
      break
    fi
    sleep 1
  done

  sleep 1
  if ! check_eos_daemon "$1" ; then
    exit 1
  fi

  post_setup_"$1"
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

RUN_EOS_CMD=( '' )

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

(launch_post_setup_script "${ROLE}" 2>&1 | tee -a "/root/INITIALIZED_${ROLE}.log" &)

echo "Starting ${ROLE} for $(rpm -q eos-server | sed s/eos-server-//g)"
cd /var/spool/eos/core && exec "${RUN_EOS_CMD[@]}"

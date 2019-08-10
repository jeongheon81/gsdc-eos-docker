#!/usr/bin/env bash

usage()
{
  echo "Usage:"
  echo "$(basename $0) <fsid> [-u <uuid>] [-d <mountpoint>] [-s <space>] [-c <configstatus>] [-g geotag]"
  echo
  echo "-h	show usage and exit"
  echo
}

[[ $1 = -h ]] && usage && exit 0

id=$1
shift

if [[ -z $id ]]; then
  echo -e "Filesystem ID (fsid) must be specified.\n"
  usage
  exit 1
fi

UUID=fst${id}
DATADIR=/data/disk${id}
SPACE=default
CONFIG=rw
GEOTAG=""
FSTHOSTNAME=$(hostname -f)

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
[[ -n $GEOTAG ]] && sed -i "s/EOS_GEOTAG=.*/EOS_GEOTAG=$GEOTAG/" /etc/sysconfig/eos

source /etc/sysconfig/eos
export EOS_MGM_URL=root://eos-mgm-test.eoscluster.cern.ch//

if [ -e /opt/eos/xrootd/bin/xrootd ]; then 
   XROOTDEXE="/opt/eos/xrootd//bin/xrootd"
else
   XROOTDEXE="/usr/bin/xrootd"
fi


echo "Starting fst${id} ..."
${XROOTDEXE} -n fst${id} -c /etc/xrd.cf.fst -l /var/log/eos/xrdlog.fst -b -Rdaemon
echo "Configuring fst${id} ..."

mkdir -p $DATADIR
echo "$UUID" > $DATADIR/.eosfsuuid
echo "${id}" > $DATADIR/.eosfsid
chown -R daemon:daemon $DATADIR
eos -b fs add -m ${id} $UUID $FSTHOSTNAME:1095 $DATADIR $SPACE $CONFIG
eos -b node set $FSTHOSTNAME:1095 on
echo "Configuration done for fst${id}"

#!/usr/bin/env bash

#------------------------------------------------------------------------------
# Utility functions
#------------------------------------------------------------------------------

function usage() {
  filename=$(basename $0)
  echo "Usage: $filename <logdir>"
  echo "  Collect logs from EOS docker containers."
  echo "  For logs to be collected, the container must start with \"eos\" and have the following keywords: mgm mq fst qdb client"
  echo "       logdir     : location where logs should be placed"
  echo ""
}

#------------------------------------------------------------------------------
# Setup
#------------------------------------------------------------------------------

# Arguments parsing
if [[ "$#" -ne 1 ]]; then
  usage
  exit 1
fi

# Create logs directory
logdir="$1"
mkdir -p ${logdir}
if [ ! -d ${logdir} ] ; then
  echo "Failed to create directory: ${logdir}"
  exit 1
fi

# Get container names for MGM/FST/MQ EOS services
EOSMGM=$(docker ps --format {{.Names}} | grep "^eos" | grep mgm)
EOSMQ=$(docker ps --format {{.Names}} | grep "^eos" | grep mq)
EOSFST=($(docker ps --format {{.Names}} | grep "^eos" | grep fst | sort ))

# Get optional container names for QDB and client services
EOSQUARKDB=$(docker ps --format {{.Names}} | grep "^eos" | grep qdb)
EOSCLIENT=($(docker ps --format {{.Names}} | grep "^eos" | grep client))

#------------------------------------------------------------------------------
# Collect logs
#------------------------------------------------------------------------------

# Collect MGM logs
docker cp ${EOSMGM}:/var/log/eos/mgm/xrdlog.mgm ${logdir}/${EOSMGM}.log

# Collect MQ logs
docker cp ${EOSMQ}:/var/log/eos/mq/xrdlog.mq ${logdir}/${EOSMQ}.log

# Collect FST logs
count=0
for container in "${EOSFST[@]}"; do
  count=$((count + 1))
  docker cp ${container}:/var/log/eos/fst${count}/xrdlog.fst ${logdir}/${container}.log
done

# Collect QDB logs
if [[ ! -z $EOSQUARKDB ]]; then
  docker cp ${EOSQUARKDB}:/var/log/eos/qdb/xrdlog.qdb ${logdir}/${EOSQUARKDB}.log
fi

# Collect client logs
for client in "${EOSCLIENT[@]}"; do
  docker cp ${client}:/var/log/eos/fuse/ ${logdir}/${client}-fuse/
  docker cp ${client}:/var/log/eos/fusex/ ${logdir}/${client}-fusex/
done

# List destination directory
ls -l ${logdir}

exit 0

#!/usr/bin/env bash
n_fst=7
n_client=1
PIDS=""

usage()
{
  echo "Usage:"
  echo "$(basename $0) [-n <number of FSTs>] [-c <number of clients>]"
  echo
  echo "-n	provide number of FST servers (default is 7)"
  echo "-c	provide number of client servers (default is 1)"
  echo
  echo "-h	show usage and exit"
  echo
}

# Read provided arguments
while getopts 'n:c:h' flag; do
  case "${flag}" in
    n) n_fst=${OPTARG} ;;
    c) n_client=${OPTARG} ;;
	h) usage
	   exit 0;;
    *) usage
	   exit 1;;
  esac
done

echo -e "\n*** Removing containers"

# Removing the FST containers in parallel
for (( i=1; i<=$n_fst; i++))
do
    FSTHOSTNAME=eos-fst${i}-test
    echo "Removing container: "$FSTHOSTNAME
    docker rm -f $FSTHOSTNAME &
    PIDS="${PIDS} $!"
done

# Removing the client containers in parallel
for (( i=1; i<=$n_client; i++))
do
    CLIENTHOSTNAME=eos-client${i}-test
    echo "Removing container: "$CLIENTHOSTNAME
    docker rm -f $CLIENTHOSTNAME &
    PIDS="${PIDS} $!"
done

# Removing all other containers from EOS cluster
for CONT in eos-mgm-test eos-mq-test eos-krb-test eos-qdb-test eos-proxy-test; do
    echo "Removing container: "$CONT
	docker rm -f ${CONT} &
    PIDS="${PIDS} $!"
done

echo -e "\n\n*** Waiting for all containers to be removed ..."
for PID in ${PIDS}; do
  wait ${PID}
done

echo -e "\n\n*** Removing eoscluster.cern.ch network"
docker network rm eoscluster.cern.ch

exit 0

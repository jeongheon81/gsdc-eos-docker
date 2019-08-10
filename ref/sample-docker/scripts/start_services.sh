#!/usr/bin/env bash
set -e

image=""
deb_cli_img=""
n_fst=7
with_qdb=0
n_client=1
with_proxy=0
geotags=()
regular_EOS_MGM_URL="EOS_MGM_URL=root://eos-mgm-test.eoscluster.cern.ch:1094"
proxy_EOS_MGM_URL="EOS_MGM_URL=root://eos-proxy-test.eoscluster.cern.ch:1094//root://eos-mgm-test.eoscluster.cern.ch:1094"

usage()
{
  echo "Usage:"
  echo "$(basename $0) -i <name of the docker image> [-n <number of FSTs>] [-c <number of clients>] [-u <debian client image>] [-g <geotag1> <geotag2> ...] [-q] [-p]"
  echo
  echo "-i	specify docker image to be used for container creation"
  echo "-n	specify desired number of FST servers (default is 7)"
  echo "-c	specify desired number of client servers (default is 1)"
  echo "-u	specify debian docker image to be used for client containers creation"
  echo "-g	specify geotags for FST servers (default is docker-test)"
  echo "-q	create container for QuarkDB server and use QuarkDB instead of In-memory Namespace"
  echo "-p	create container for proxy server and use it as cluster access point for EOS clients"
  echo
  echo "-h	show usage and exit"
  echo
}

# Read provided arguments
while getopts 'i:n:c:u:g:qph' flag; do
  case "${flag}" in
    i) image="${OPTARG}" ;;
    n) n_fst="${OPTARG}" ;;
    c) n_client="${OPTARG}" ;;
    u) deb_cli_img="${OPTARG}" ;;
    g) if [[ ${OPTARG} != -* ]]; then
        geotags="${OPTARG}"
        until [[ $(eval "echo \${$OPTIND}") =~ ^-.* ]] || [ -z $(eval "echo \${$OPTIND}") ]; do
          geotags+=($(eval "echo \${$OPTIND}"))
          OPTIND=$((OPTIND + 1))
        done
      else
        echo "Geotags starting with dash (-) cannot be used."
        exit 1
      fi ;;
    q) with_qdb=1 ;;
    p) with_proxy=1 ;;
    h) usage
      exit 0;;
    *) usage
      exit 1;;
  esac
done

if [[ $image == "" ]]; then
  echo "Docker image to be used for container creation must be specified using -i argument."
  exit 1
fi

if [[ ${#geotags[@]} != 0 ]] && [[ $n_fst != ${#geotags[@]} ]]; then
  echo "Number of geotags (${#geotags[@]}) is not the same as number of FST nodes (${n_fst})"
  exit 1
fi

# Creation of the network for EOS cluster
echo -e "\n\n*** Creation of the network for EOS cluster"
docker network create eoscluster.cern.ch || true

# Kerberos server creation and setup
echo -e "\n\n*** Kerberos server creation and setup"
docker run -dit -h eos-krb-test.eoscluster.cern.ch --name eos-krb-test --net=eoscluster.cern.ch --net-alias=eos-krb-test $image
docker exec -i eos-krb-test /kdc.sh

# MQ server creation and setup
echo -e "\n\n*** MQ server creation and setup"
docker run -dit -h eos-mq-test.eoscluster.cern.ch --name eos-mq-test --net=eoscluster.cern.ch --net-alias=eos-mq-test $image
docker exec -i eos-mq-test /eos_mq_setup.sh

# MGM server creation
echo -e "\n\n*** MGM server creation"
docker run --privileged -dit -h eos-mgm-test.eoscluster.cern.ch --name eos-mgm-test --net=eoscluster.cern.ch --net-alias=eos-mgm-test $image

if [[ $with_qdb == 1 ]]; then
echo -e "\n\n*** QuarkDB server creation and setup"
# Namespace library which will be loaded by the MGM should be changed to enable QuarkDB mode
docker exec -i eos-mgm-test sed -i 's/libEosNsInMemory.so/libEosNsQuarkdb.so/g' /etc/xrd.cf.mgm
# QuarkDB server creation and setup
docker run --privileged -dit -h eos-qdb-test.eoscluster.cern.ch --name eos-qdb-test --net=eoscluster.cern.ch --net-alias=eos-qdb-test $image
docker exec -i eos-qdb-test /eos_qdb_setup.sh
fi

if [[ $with_proxy == 1 ]]; then
echo -e "\n\n*** Proxy server creation and setup"
# Proxy server creation
docker run --privileged -dit -h eos-proxy-test.eoscluster.cern.ch --name eos-proxy-test --net=eoscluster.cern.ch --net-alias=eos-proxy-test $image
# Start XRootD proxy service
docker exec -i eos-proxy-test /eos_proxy_setup.sh
fi

# Applying Kerberos keytab to EOS cluster
echo -e "\n\n*** Applying Kerberos keytab on EOS cluster"
TMP_EOS_KEYTAB=mktemp
docker cp eos-krb-test:/root/eos.keytab $TMP_EOS_KEYTAB
docker cp $TMP_EOS_KEYTAB eos-mgm-test:/etc/eos.krb5.keytab
rm -f $TMP_EOS_KEYTAB

# MGM server setup
echo -e "\n\n*** MGM server setup"
docker exec -i eos-mgm-test /eos_mgm_setup.sh

# FST servers parallel creation
echo -e "\n\n*** FST servers parallel creation"
FAILURE=0
PIDS=""

for (( i=1; i<=$n_fst; i++ )); do
  FSTHOSTNAME=eos-fst${i}-test
  docker run --privileged -dit -h $FSTHOSTNAME.eoscluster.cern.ch --name $FSTHOSTNAME --net=eoscluster.cern.ch --net-alias=$FSTHOSTNAME --mount "type=volume,src=nfsvolume,dst=/data/disk00,volume-driver=local,volume-opt=type=nfs,volume-opt=device=:/ifs/service/eos_kisti/data03,\"volume-opt=o=addr=pool0.gsn3.sdfarm.kr,rw,nfsvers=4\"" $image &
  PIDS="${PIDS} $!"
  sleep 0.1
done

for PID in ${PIDS}; do
  wait ${PID} || let "FAILURE=1"
done

if [ "${FAILURE}" == "1" ]; then
  echo "Failed to start one of the FSTs"
  exit 1
fi

# FST servers parallel setup
echo -e "\n\n*** FST servers parallel setup"
PIDS=""

for (( i=1; i<=$n_fst; i++ )); do
  FSTHOSTNAME=eos-fst${i}-test
  docker exec -i $FSTHOSTNAME /eos_fst_setup.sh $i ${geotags[i-1]:+"-g${geotags[i-1]}"} &
  PIDS="${PIDS} $!"
  sleep 0.1
done

for PID in ${PIDS}; do
  wait ${PID} || let "FAILURE=1"
done

if [ "${FAILURE}" == "1" ]; then
  echo "Failed to configure one of the FSTs"
  exit 1
fi

# Enabling default space with quota disabled and booting filesystems
echo -e "\n\n*** Enabling default space with quota disabled and booting filesystems"
docker exec -i eos-mgm-test /eos_mgm_fs_setup.sh $n_fst

# Client servers creation and setup
echo -e "\n\n*** Client servers creation and setup"
for (( i=1; i<=$n_client; i++ )); do
  CLIENTHOSTNAME=eos-client${i}-test
  docker run --privileged --pid=host -dit -h ${CLIENTHOSTNAME}.eoscluster.cern.ch --name ${CLIENTHOSTNAME} --net=eoscluster.cern.ch --net-alias=${CLIENTHOSTNAME} ${deb_cli_img:-$image}

  # Kerberos client configuration
  docker exec -i eos-krb-test cat /root/admin1.keytab | docker exec -i ${CLIENTHOSTNAME} bash -c "cat > /root/admin1.keytab"
  docker exec -i ${CLIENTHOSTNAME} kinit -kt /root/admin1.keytab admin1@TEST.EOS
  docker exec -i ${CLIENTHOSTNAME} kvno host/eos-mgm-test.eoscluster.cern.ch

  if [[ $with_proxy == 1 ]];
    then
    # Set created proxy server as cluster access point for EOS client
      docker exec -i ${CLIENTHOSTNAME} bash -c "echo 'export '"$proxy_EOS_MGM_URL" >> /root/.bashrc; source /root/.bashrc"
  else
    # Set MGM server as cluster access point for EOS client
      docker exec -i ${CLIENTHOSTNAME} bash -c "echo 'export '"$regular_EOS_MGM_URL" >> /root/.bashrc; source /root/.bashrc"
  fi

done

#!/usr/bin/env bash
set -e

image=""
deb_cli_img=""
n_fst=7
with_qdb=0
n_client=1
with_proxy=0
geotags=()
regular_EOS_MGM_URL="EOS_MGM_URL=root://mgm.eos-kisti.sdfarm.kr:1094"
proxy_EOS_MGM_URL="EOS_MGM_URL=root://proxy.eos-kisti.sdfarm.kr:1094//root://mgm.eos-kisti.sdfarm.kr:1094"

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
docker network create eos-kisti.sdfarm.kr || true

# Kerberos server creation and setup
echo -e "\n\n*** Kerberos server creation and setup"
docker run -dit -h krb.eos-kisti.cern.ch --name krb --net=eos-kisti.sdfarm.kr --net-alias=krb $image
docker exec -i krb /kdc.sh

# MQ server creation and setup
echo -e "\n\n*** MQ server creation and setup"
docker run -dit -h mq.eos-kisti.cern.ch --name mq --net=eos-kisti.sdfarm.kr --net-alias=mq $image
docker exec -i mq /eos_mq_setup.sh

# MGM server creation
echo -e "\n\n*** MGM server creation"
docker run --privileged -dit -h mgm.eos-kisti.sdfarm.kr --name mgm --net=eos-kisti.sdfarm.kr --net-alias=mgm $image

if [[ $with_qdb == 1 ]]; then
echo -e "\n\n*** QuarkDB server creation and setup"
# Namespace library which will be loaded by the MGM should be changed to enable QuarkDB mode
docker exec -i mgm sed -i 's/libEosNsInMemory.so/libEosNsQuarkdb.so/g' /etc/xrd.cf.mgm
# QuarkDB server creation and setup
docker run --privileged -dit -h qdb.eos-kisti.sdfarm.kr --name qdb --net=eos-kisti.sdfarm.kr --net-alias=qdb $image
docker exec -i qdb /eos_qdb_setup.sh
fi

if [[ $with_proxy == 1 ]]; then
echo -e "\n\n*** Proxy server creation and setup"
# Proxy server creation
docker run --privileged -dit -h proxy.eos-kisti.sdfarm.kr --name proxy --net=eos-kisti.sdfarm.kr --net-alias=proxy $image
# Start XRootD proxy service
docker exec -i proxy /eos_proxy_setup.sh
fi

# Applying Kerberos keytab to EOS cluster
echo -e "\n\n*** Applying Kerberos keytab on EOS cluster"
TMP_EOS_KEYTAB=mktemp
docker cp krb:/root/eos.keytab $TMP_EOS_KEYTAB
docker cp $TMP_EOS_KEYTAB mgm:/etc/eos.krb5.keytab
rm -f $TMP_EOS_KEYTAB

# MGM server setup
echo -e "\n\n*** MGM server setup"
docker exec -i mgm /eos_mgm_setup.sh

# FST servers parallel creation
echo -e "\n\n*** FST servers parallel creation"
FAILURE=0
PIDS=""

for (( i=1; i<=$n_fst; i++ )); do
  FSTHOSTNAME=fst${i}
  docker run --privileged -dit -h $FSTHOSTNAME.eos-kisti.sdfarm.kr --name $FSTHOSTNAME --net=eos-kisti.sdfarm.kr --net-alias=$FSTHOSTNAME -v my-nfs-vol:/data $image &
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
  FSTHOSTNAME=fst${i}
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
docker exec -i mgm /eos_mgm_fs_setup.sh $n_fst

# Client servers creation and setup
echo -e "\n\n*** Client servers creation and setup"
for (( i=1; i<=$n_client; i++ )); do
  CLIENTHOSTNAME=client${i}
  docker run --privileged --pid=host -dit -h ${CLIENTHOSTNAME}.eos-kisti.sdfarm.kr --name ${CLIENTHOSTNAME} --net=eos-kisti.sdfarm.kr --net-alias=${CLIENTHOSTNAME} ${deb_cli_img:-$image}

  # Kerberos client configuration
  docker exec -i krb cat /root/admin1.keytab | docker exec -i ${CLIENTHOSTNAME} bash -c "cat > /root/admin1.keytab"
  docker exec -i ${CLIENTHOSTNAME} kinit -kt /root/admin1.keytab admin1@KISTI.EOS
  docker exec -i ${CLIENTHOSTNAME} kvno host/mgm.eos-kisti.sdfarm.kr

  if [[ $with_proxy == 1 ]];
    then
    # Set created proxy server as cluster access point for EOS client
      docker exec -i ${CLIENTHOSTNAME} bash -c "echo 'export '"$proxy_EOS_MGM_URL" >> /root/.bashrc; source /root/.bashrc"
  else
    # Set MGM server as cluster access point for EOS client
      docker exec -i ${CLIENTHOSTNAME} bash -c "echo 'export '"$regular_EOS_MGM_URL" >> /root/.bashrc; source /root/.bashrc"
  fi

done

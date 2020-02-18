#!/usr/bin/env bash

hosts=(jbod-node-{01..09}.foo.com)

rm -rf tmp/playbooks-*
rm -rf tmp/keytab

for s in "${hosts[@]}";do
  ssh $s "rm -rf /etc/consul/*"
  ssh $s "rm -rf /etc/loki/*"
  ssh $s "rm -rf /etc/grafana/*"
  ssh $s "rm -rf /etc/eos-docker/*"
  ssh $s "rm -rf /var/eos/*/*"
  ssh $s "rm -rf /var/eos/*/.eos*"

  containers=$(ssh $s "docker container ls -a"|grep -v "^CONTAINER"|awk '{print $1}')
  if [ -n "$containers" ];then
    ssh $s docker rm -f $containers
  fi
  ssh $s docker container prune -f
  ssh $s docker volume prune -f
done

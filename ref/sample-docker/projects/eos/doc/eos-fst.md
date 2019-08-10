
# Setup FST server(s) from MGM

> Note: All FSTs are controlled from MGM pysical machine `[root@eosm01-iep-grid]` and `NOT` from MGM container [root@eosm01-iep-grid (eos-docker mgm)]

## FST prerequisites

## FST installation

Add FST hostnames to /root/eos/eos-docker-fst.cf
```
[root@eosm01-iep-grid ~]# echo "eosf01-iep-grid.saske.sk" >> /root/eos/eos-docker-fst.cf
```
> Note : We assume that you have without password ssh to fsts

To setup and start fst run following command
```
[root@eosm01-iep-grid ~]# eos-docker start fsts
```
When process finishes, one can look via eos-mgm container that new node showed up
```
[root@eosm01-iep-grid ~]# ed-enter
[root@eosm01-iep-grid (eos-docker mgm) /]# eos -b node ls
┌──────────┬────────────────────────────────┬────────────────┬──────────┬────────────┬──────┬──────────┬────────┬────────┬────────────────┬─────┐
│type      │                        hostport│          geotag│    status│      status│  txgw│ gw-queued│  gw-ntx│ gw-rate│  heartbeatdelta│ nofs│
└──────────┴────────────────────────────────┴────────────────┴──────────┴────────────┴──────┴──────────┴────────┴────────┴────────────────┴─────┘
 nodesview     eosf01-iep-grid.saske.sk:1095             test     online           on    off          0       10      120                2    0 
[root@eosm01-iep-grid (eos-docker mgm) /]# exit
[root@eosm01-iep-grid ~]#
```

## Adding or synchronizing disks to file server
> Mount all data disks to /var/eos/fs/XXX where XXX is 0,1,...,N disks/mounting points

Run from mgm machine (not from docker container)
```
[root@eosm01-iep-grid ~]# eos-docker disk-sync fsts
```

## Open ports for FST
Via `eos-docker` from MGM
```
[root@eosm01-iep-grid ~]# eos-docker firewall-add fsts
or
[root@eosm01-iep-grid ~]# eos-docker firewall-add <hostname>
```
or manualy on FSTs itself
```
firewall-cmd --add-port=1095/tcp
firewall-cmd --add-port=1095/tcp --permanent
```
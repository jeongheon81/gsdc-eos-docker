# EOS docker

## Prerequisites

### Install docker and start service
> Note: We assume that MGM and all FSTs has to have docker installed and it is running

One needs to install following commands to install and start docker
```
yum install -y docker docker-compose
systemctl start docker
systemctl enable docker
```

# EOS docker installation

## Install eos-docker-utils
> Note: eos-docker-utils needs to be installed on `MGM only`

Install eos repository
```
yum install http://storage-ci.web.cern.ch/storage-ci/eos/citrine/tag/el-7/x86_64/eos-citrine-repo-1-1.noarch.rpm
```
Install `eos-docker-utils`
```
yum install eos-docker-utils
```

## Using `eos-docker`
> Note: It is assumed that `MGM->FSTs` there without password ssh access

> Note: One will run all commands from `MGM only`

## Super quick start from your laptop (for tesing)
>  One can setup full stack on one machine for testing purposes. If you need to install storage in production go to next section (MGM and FST setup)

```
[root@vala ~]# mkdir -p /var/eos/fs/0
[root@vala ~]# eos-docker
[root@vala ~]# sed -i 's/^export ED_NODE_TYPE=.*/export ED_NODE_TYPE="mgmfst"/' eos/eos-docker.cf
[root@vala ~]# eos-docker init
[root@vala ~]# eos-docker start
[root@vala ~]# eos-docker disk-sync
[root@vala ~]# eos -b node ls
┌──────────┬────────────────────────────────┬────────────────┬──────────┬────────────┬──────┬──────────┬────────┬────────┬────────────────┬─────┐
│type      │                        hostport│          geotag│    status│      status│  txgw│ gw-queued│  gw-ntx│ gw-rate│  heartbeatdelta│ nofs│
└──────────┴────────────────────────────────┴────────────────┴──────────┴────────────┴──────┴──────────┴────────┴────────┴────────────────┴─────┘
 nodesview          vala.dyndns.cern.ch:1095             test     online           on    off          0       10      120                1     1 
[root@vala ~]# eos -b fs ls
┌────────────────────────┬────┬──────┬────────────────────────────────┬────────────────┬────────────────┬────────────┬──────────────┬────────────┬────────┬────────────────┐
│host                    │port│    id│                            path│      schedgroup│          geotag│        boot│  configstatus│ drainstatus│  active│          health│
└────────────────────────┴────┴──────┴────────────────────────────────┴────────────────┴────────────────┴────────────┴──────────────┴────────────┴────────┴────────────────┘
 vala.dyndns.cern.ch      1095      1                    /var/eos/fs/0        default.0             test       booted             rw      nodrain   online              N/A 

[root@vala ~]# eos-b space ls
bash: eos-b: command not found...
[root@vala ~]# eos -b space ls
┌──────────┬────────────────┬────────────┬────────────┬──────┬─────────┬───────────────┬──────────────┬─────────────┬─────────────┬──────┬──────────┬───────────┬───────────┬──────┬────────┬───────────┬──────┬────────┬───────────┐
│type      │            name│   groupsize│    groupmod│ N(fs)│ N(fs-rw)│ sum(usedbytes)│ sum(capacity)│ capacity(rw)│ nom.capacity│ quota│ balancing│  threshold│  converter│   ntx│  active│        wfe│   ntx│  active│ intergroup│
└──────────┴────────────────┴────────────┴────────────┴──────┴─────────┴───────────────┴──────────────┴─────────────┴─────────────┴──────┴──────────┴───────────┴───────────┴──────┴────────┴───────────┴──────┴────────┴───────────┘
 spaceview           default            0           24      1         1       16.82 GiB      97.93 GiB     97.93 GiB           0 B    off        off          20         off      2        0                  0        0         off 
```

Full ouput is located [here](doc/eos-super-quickstart.md)

## Cleanup eos-docker
```
eos-docker clean all
rm -rf /root/eos
rm -rf /var/eos/fs/0
```
and now you are back where you started.

One can do full cleanup like deleting all docker images and so with :
```
[root@vala ~]# docker stop $(docker ps -aq)> /dev/null 2>&1
[root@vala ~]# docker rm $(docker ps -aq)> /dev/null 2>&1
[root@vala ~]# docker rmi -f $(docker images -q) > /dev/null 2>&1
```

# MGM and FST setup for production

* [EOS MGM](doc/eos-mgm.md)
* [EOS FST](doc/eos-fst.md)


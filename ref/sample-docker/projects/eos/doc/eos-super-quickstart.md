# Super quick start

```
[root@vala ~]# mkdir -p /var/eos/fs/0
[root@vala ~]# eos-docker
eos-docker 0.9.4

 
Default values are saved in '/root/eos/eos-docker.cf.default'.
   Note : Don't modify it directly, but 'user config' instead.
 
User config file '/root/eos/eos-docker.cf' was generated. Please modify it accordingly .
 
 
For simple EOS
  Modify '/root/eos/eos-docker.cf'
  eos-docker init
 
For ALICE SE
  ln -sfn /root/eos/eos-docker.cf.alice /root/eos/eos-docker.cf
  Modify '/root/eos/eos-docker.cf'
  eos-docker init
 
[root@vala ~]# sed -i 's/^export ED_NODE_TYPE=.*/export ED_NODE_TYPE="mgmfst"/' eos/eos-docker.cf
[root@vala ~]# eos-docker init
Init EOS docker '' ...
Unable to find image 'gitlab-registry.cern.ch/eos/eos-docker/eos-prod:latest' locally
Trying to pull repository gitlab-registry.cern.ch/eos/eos-docker/eos-prod ... 
sha256:facb7c175c91bae29426a054cd45011472aa2efce06ab342c9622b32ba1f5d0c: Pulling from gitlab-registry.cern.ch/eos/eos-docker/eos-prod
371eb7684dcb: Pull complete 
5651a67a1b91: Pull complete 
cf9c6af10585: Pull complete 
8a5e2958062c: Pull complete 
42266d1b4224: Pull complete 
5e34578caf02: Pull complete 
abc668b12c6a: Pull complete 
47993894403d: Pull complete 
e8131e16dea2: Pull complete 
7a84a0bb23b7: Pull complete 
fd412a4962c8: Pull complete 
8f3582bdd5c8: Pull complete 
2d470970a8ff: Pull complete 
4427717f3960: Pull complete 
Digest: sha256:facb7c175c91bae29426a054cd45011472aa2efce06ab342c9622b32ba1f5d0c
Status: Downloaded newer image for gitlab-registry.cern.ch/eos/eos-docker/eos-prod:latest
Init of EOS docker '' done ...
[root@vala ~]# eos-docker start
Starting mgm ...
Running eos-mgmfst ...
Creating eos-mgmfst ...
ED_DOCKER_ARGS_BEGIN: --privileged --net=host -ti -v /sys/fs/cgroup:/sys/fs/cgroup:ro -v /root/eos:/root/eos -v /root/eos/var/eos:/var/eos -v /root/eos/var/log/eos:/var/log/eos
ED_DOCKER_ARGS_END:  -p 19999:19999
Creating eos-mgmfst ...
db956e41d4f571415b6d8954b19e9b27157e295792ce986ea684e560253c924a
Starting eos-mgmfst ...
eos-mgmfst
getsebool:  SELinux is disabled
Doing 'systemctl status eos@mgm in 5 sec ...
eos@mgm is running
Doing EOS init ...
success: set vid [  eos.rgid=0 eos.ruid=0 mgm.cmd=vid mgm.subcmd=set mgm.vid.auth=sss mgm.vid.cmd=map mgm.vid.gid=0 mgm.vid.key=<key> mgm.vid.pattern=<pwd> mgm.vid.uid=0 ]
success: set vid [  eos.rgid=0 eos.ruid=0 mgm.cmd=vid mgm.subcmd=set mgm.vid.auth=https mgm.vid.cmd=map mgm.vid.gid=0 mgm.vid.key=<key> mgm.vid.pattern=<pwd> mgm.vid.uid=0 ]
success: set vid [  eos.rgid=0 eos.ruid=0 mgm.cmd=vid mgm.subcmd=set mgm.vid.auth=tident mgm.vid.cmd=map mgm.vid.gid=0 mgm.vid.key=<key> mgm.vid.pattern="*@vala" mgm.vid.uid=0 ]
info: creating space 'default'
info: creating group 'default.0'
info: creating group 'default.1'
info: creating group 'default.2'
info: creating group 'default.3'
info: creating group 'default.4'
info: creating group 'default.5'
info: creating group 'default.6'
info: creating group 'default.7'
info: creating group 'default.8'
info: creating group 'default.9'
info: creating group 'default.10'
info: creating group 'default.11'
info: creating group 'default.12'
info: creating group 'default.13'
info: creating group 'default.14'
info: creating group 'default.15'
info: creating group 'default.16'
info: creating group 'default.17'
info: creating group 'default.18'
info: creating group 'default.19'
info: creating group 'default.20'
info: creating group 'default.21'
info: creating group 'default.22'
info: creating group 'default.23'
info: creating group 'default.24'
info: creating group 'default.25'
info: creating group 'default.26'
info: creating group 'default.27'
info: creating group 'default.28'
info: creating group 'default.29'
info: creating group 'default.30'
info: creating group 'default.31'
info: creating group 'default.32'
info: creating group 'default.33'
info: creating group 'default.34'
info: creating group 'default.35'
success: setting scaninterval=1814400
success: auto-repair is enabled!
success: setting graceperiod=3600
success: setting drainperiod=3600
success: setting headroom=5000000000
[root@vala ~]# eos-docker disk-sync
Searching for data disks in /var/eos/fs ...
Doing 'docker exec eos-mgmfst eosfstregister -i /var/eos/fs/ default:1'
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
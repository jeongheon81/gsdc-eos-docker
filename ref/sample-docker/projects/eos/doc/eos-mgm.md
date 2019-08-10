# Setup MGM

## Generate EOS docker config file

Simply run `eos-docker` to generate EOS docker config file and follow instruction
```
[root@eosm01-iep-grid ~]# eos-docker
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

```

Edit config eos-docker.cf and run init: 
```
[root@eosm01-iep-grid ~]# eos-docker init
Init EOS docker 'simple' ...
Unable to find image 'gitlab-registry.cern.ch/eos/eos-docker/eos-prod:latest' locally
Trying to pull repository gitlab-registry.cern.ch/eos/eos-docker/eos-prod ... 
sha256:f5953fd9e727ec5fc5c84b0f6234e78065a428c42a8fb482e5c1f7479f3ffa07: Pulling from gitlab-registry.cern.ch/eos/eos-docker/eos-prod
371eb7684dcb: Pull complete 
5651a67a1b91: Pull complete 
479b41373624: Pull complete 
db06622251e7: Pull complete 
c698049db915: Pull complete 
f6b488040d6b: Pull complete 
58c6cd65455a: Pull complete 
05f176b06133: Pull complete 
762afae09e69: Pull complete 
ba152ca8aff0: Pull complete 
b67ca6caebd9: Pull complete 
d97fac02757a: Pull complete 
3bf94cf9fdc5: Pull complete 
6325b5938ce2: Pull complete 
Digest: sha256:f5953fd9e727ec5fc5c84b0f6234e78065a428c42a8fb482e5c1f7479f3ffa07
Status: Downloaded newer image for gitlab-registry.cern.ch/eos/eos-docker/eos-prod:latest
Init of EOS docker 'simple' done ...
```

Now there should be ```/root/eos``` directory which contains all config files ```/root/eos/etc``` and all ```/var/eos``` and ```/var/log``` directory in ```/root/eos/var```.

## Setup certificate (For ALICE only)
```
[root@eosm01-iep-grid ~]# eos-docker cert-update
```

## Starting EOS MGM docker image
```
[root@eosm01-iep-grid ~]# eos-docker start
```
Setup of MGM is finished. One can try if `eos` is working

## Run `eos`

```
[root@eosm01-iep-grid ~]# ed-eos
# ---------------------------------------------------------------------------
# EOS  Copyright (C) 2011-2017 CERN/Switzerland
# This program comes with ABSOLUTELY NO WARRANTY; for details type `license'.
# This is free software, and you are welcome to redistribute it 
# under certain conditions; type `license' for details.
# ---------------------------------------------------------------------------
EOS_INSTANCE=eostest
EOS_SERVER_VERSION=4.2.12 EOS_SERVER_RELEASE=1
EOS_CLIENT_VERSION=4.2.12 EOS_CLIENT_RELEASE=1
EOS Console [root://localhost] |/> 
```
> More info on `eos` or `ed-eos` commands are eat the end on this page

## Open ports on MGM
> Firewall via `eos-docker`
>
>   `eos-docker firewall-print` : Print ports to be enabled
>
>   `eos-docker firewall-add` : Adds ports
>
>   `eos-docker firewall-remove` : Remove ports
>

or by hand
```
firewall-cmd --add-port=1094/tcp
firewall-cmd --add-port=1094/tcp --permanent
firewall-cmd --add-port=1097/tcp
firewall-cmd --add-port=1097/tcp --permanent
firewall-cmd --add-port=1100/tcp
firewall-cmd --add-port=1100/tcp --permanent
```
> Also one can run '`eos-docker firewall-print all|mgm|fsts`' and it will print all ports needed for MGM and FST, but one have to setup at least one FST

## Stoping EOS MGM docker image
```
[root@eosm01-iep-grid ~]# eos-docker stop
```

## Restarting EOS MGM docker image
```
[root@eosm01-iep-grid ~]# eos-docker restart
```

## Entering EOS MGM docker image
`ed-enter` will enter inside docker container. When one enter the container `(eos-docker mgm)` is appended in prompt. This is done to inform user that you are running in container and not on host machine

```
[root@eosm01-iep-grid ~]# ed-enter
[root@eosm01-iep-grid (eos-docker mgm) /]#
```

## Running `eos` client from MGM

One can run eos command directly from host machine. There are two possible option

### Run `ed-eos`
```
[root@eosm01-iep-grid ~]# ed-eos
# ---------------------------------------------------------------------------
# EOS  Copyright (C) 2011-2017 CERN/Switzerland
# This program comes with ABSOLUTELY NO WARRANTY; for details type `license'.
# This is free software, and you are welcome to redistribute it 
# under certain conditions; type `license' for details.
# ---------------------------------------------------------------------------
EOS_INSTANCE=eostest
EOS_SERVER_VERSION=4.2.12 EOS_SERVER_RELEASE=1
EOS_CLIENT_VERSION=4.2.12 EOS_CLIENT_RELEASE=1
EOS Console [root://localhost] |/> 
```
## Run `eos` cmd directly

When eos-client is not installed on host machine (executable `eos` is not found), one can run `eos` directly and it is the same command as `ed-eos`. In other case, it is acting as normal `eos` command

```
[root@eosm01-iep-grid ~]# eos
# ---------------------------------------------------------------------------
# EOS  Copyright (C) 2011-2017 CERN/Switzerland
# This program comes with ABSOLUTELY NO WARRANTY; for details type `license'.
# This is free software, and you are welcome to redistribute it 
# under certain conditions; type `license' for details.
# ---------------------------------------------------------------------------
EOS_INSTANCE=eostest
EOS_SERVER_VERSION=4.2.12 EOS_SERVER_RELEASE=1
EOS_CLIENT_VERSION=4.2.12 EOS_CLIENT_RELEASE=1
EOS Console [root://localhost] |/> 
```

## Setup some FSTs

One can continue here : [EOS FST](eos-fst.md)

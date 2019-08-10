#!/usr/bin/env bash

source /etc/sysconfig/eos

if [ -e /opt/eos/xrootd/bin/xrootd ]; then
   XROOTDEXE="/opt/eos/xrootd//bin/xrootd"
else
   XROOTDEXE="/usr/bin/xrootd"
fi

${XROOTDEXE} -n mq -c /etc/xrd.cf.mq -l /var/log/eos/xrdlog.mq -b -Rdaemon

#!/usr/bin/env bash

# Start XRootD proxy service
if [ -e /opt/eos/xrootd/bin/xrootd ]; then
   XROOTDEXE="/opt/eos/xrootd//bin/xrootd"
else
   XROOTDEXE="/usr/bin/xrootd"
fi

${XROOTDEXE} -n proxy -c /etc/xrootd/xrootd-fwd-proxy.cfg -l /var/log/eos/xrdlog.proxy -b -Rdaemon

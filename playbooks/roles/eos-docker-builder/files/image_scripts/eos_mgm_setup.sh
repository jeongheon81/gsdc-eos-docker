#!/usr/bin/env bash

source /etc/sysconfig/eos

chown daemon:daemon /etc/eos.krb5.keytab

if [ -e /opt/eos/xrootd/bin/xrootd ]; then
   XROOTDEXE="/opt/eos/xrootd//bin/xrootd"
else
   XROOTDEXE="/usr/bin/xrootd"
fi

${XROOTDEXE} -n mgm -c /etc/xrd.cf.mgm -m -l /var/log/eos/xrdlog.mgm -b -Rdaemon

# Enable sss authentication for the FSTs to connect to the MGM
eos -b vid enable sss

# let the force be with admin1 (typically krb-authenticated on clients)
useradd admin1
eos -b vid set membership admin1 +sudo

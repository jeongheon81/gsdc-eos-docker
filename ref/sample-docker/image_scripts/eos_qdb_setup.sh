#!/usr/bin/env bash

quarkdb-create --path /var/quarkdb/node-0
chown -R daemon:daemon /var/quarkdb/node-0
/usr/bin/xrootd -n qdb -c /etc/xrd.cf.quarkdb -l /var/log/eos/xrdlog.qdb -b -Rdaemon
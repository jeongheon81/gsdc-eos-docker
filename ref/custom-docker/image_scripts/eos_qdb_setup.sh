#!/usr/bin/env bash

quarkdb-create --path {{ redis_database }} ----clusterID {{ uuid_cluster_id }} --nodes {{ eos_qdb_cluster_nodes TODO CSV }}
chown -R daemon:daemon {{ redis_database }}
/usr/bin/xrootd -n qdb -c /etc/xrd.cf.quarkdb -l /var/log/eos/xrdlog.qdb -b -Rdaemon

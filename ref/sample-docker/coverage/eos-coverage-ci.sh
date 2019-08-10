#!/usr/bin/env bash

#------------------------------------------------------------------------------
# File: eos-coverage-ci
# Author: Mihai Patrascoiu - CERN
#------------------------------------------------------------------------------

# *****************************************************************************
# EOS - the CERN Disk Storage System
# Copyright (C) 2019 CERN/Switzerland
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
# *****************************************************************************

#------------------------------------------------------------------------------
# Description: Script executing the EOS CI testing jobs and aggregating
#              the coverage results. It is meant to be executed in the 
#              eos-docker setup, on images built with Dockverfile_coverage.
#                
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Utility functions
#------------------------------------------------------------------------------

function print_header() {
  local message=$1

  if [[ $stage -gt 0 ]]; then
    echo ""
  fi

  echo "========================================"
  echo $message
  echo "========================================"

  stage=$((stage + 1))
}

# Run a command in parallel on the array of containers.
# Waits for all the commands to finish before continuing.
function run_on_containers() {
  echo "Executing: $@"

  for container in "${CONTAINERS[@]}"; do
    docker exec -i $container "$@" &    
  done

  wait
}

#------------------------------------------------------------------------------
# Global setup
#------------------------------------------------------------------------------

# Get container names running an EOS service
EOSCONTAINERS=($(docker ps --format {{.Names}} \
  | grep -v eos-krb-test\
  | grep -v eos-client))

# EOS service containers plus the client
CONTAINERS=(${EOSCONTAINERS[@]} eos-client1-test)

# Identify installed release version (rpm release without platform info)
EOSRELEASE=$(docker exec -i eos-mgm-test ls /usr/src/debug | grep eos)

SRCPATH=/root/rpmbuild/BUILD/${EOSRELEASE}
COVPATH=/var/eos/coverage

# Stage counter
stage=0

#------------------------------------------------------------------------------
# Execute coverage steps:
#   - Initialize containers
#   - Run all system tests, unit tests and fuse tests
#   - Flush all coverage data
#   - Perform coverage report on each container
#   - Aggregate all coverage reports
#   - Generate HTML report
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
print_header "Initializing containers"
run_on_containers scl enable devtoolset-6 "lcov --quiet --capture --initial --no-external --directory $COVPATH --base-directory $SRCPATH --config-file /eos-coverage/eoslcov.rc --output-file /eos-coverage/coverage-base.info" 2>&1 | egrep -v "^geninfo:"

#------------------------------------------------------------------------------
print_header "Running system tests"
docker exec -i eos-mgm-test eos-instance-test-ci

#------------------------------------------------------------------------------
print_header "Running stress tests"
docker exec -i eos-mgm-test hammer-runner.py --strict-exit-code 1 --gitlab --url eos-mgm-test.eoscluster.cern.ch//eos/dockertest/hammer --protocols xroot --threads 100 --operations write stat read delete --runs 3 --nfiles 10000

#------------------------------------------------------------------------------
print_header "Running fuse(x) tests"
docker exec -i eos-client1-test git clone https://gitlab.cern.ch/dss/eosclient-tests.git
docker exec -di eos-client1-test /bin/bash -c 'mkdir /eos1/; mount -t fuse eosxd /eos1/'
docker exec -di eos-client1-test /bin/bash -c 'mkdir /eos2/; mount -t fuse eosxd /eos2/'
docker exec -i -e EOS_MGM_URL=root://eos-mgm-test.eoscluster.cern.ch eos-client1-test eos fuse mount /eos_fuse1
docker exec -i -e EOS_MGM_URL=root://eos-mgm-test.eoscluster.cern.ch eos-client1-test eos fuse mount /eos_fuse2
docker exec -i eos-client1-test /bin/bash -c 'mkdir /eos1/dockertest/fusex_tests/; cd /eos1/dockertest/fusex_tests/; fusex-benchmark'
docker exec -i -u eos-user eos-client1-test python /eosclient-tests/run.py --workdir="/eos1/dockertest /eos2/dockertest" ci
docker exec -i eos-client1-test python /eosclient-tests/run.py --workdir="/eos_fuse1/dockertest /eos_fuse2/dockertest" ci
docker exec -i eos-client1-test /bin/bash -c 'umount /eos1 /eos2 /eos_fuse1 /eos_fuse2'

#------------------------------------------------------------------------------
print_header "Running unit tests"
docker exec -i eos-mgm-test eos-unit-tests
docker exec -i eos-mgm-test eos-fst-unit-tests

#------------------------------------------------------------------------------
print_header "Flushing coverage data"
# Avoid the eos-client container in this step as it uses the same process tree as the host
CONTAINERS=(${EOSCONTAINERS[@]})
run_on_containers chown -R daemon:daemon ${COVPATH}
run_on_containers /bin/bash -c 'kill -s SIGPROF $(pidof xrootd)'
CONTAINERS=(${EOSCONTAINERS[@]} eos-client1-test)

#------------------------------------------------------------------------------
print_header "Performing individual coverage report"
run_on_containers scl enable devtoolset-6 "lcov --quiet --capture --no-external --directory $COVPATH --base-directory $SRCPATH --config-file /eos-coverage/eoslcov.rc --output-file /eos-coverage/coverage-test.info" 2>&1 | egrep -v "^geninfo: WARNING|Cannot open source file"
run_on_containers /bin/bash -c 'lcov --add-tracefile /eos-coverage/coverage-base.info --add-tracefile /eos-coverage/coverage-test.info --config-file /eos-coverage/eoslcov.rc --output-file /eos-coverage/$(hostname -s).info'

#------------------------------------------------------------------------------
print_header "Aggregating reports"
mkdir -p /tmp/eos-coverage-traces/

for container in "${CONTAINERS[@]}"; do
  docker cp ${container}:/eos-coverage/${container}.info /tmp/eos-coverage-traces/
done
docker cp /tmp/eos-coverage-traces/ eos-mgm-test:/eos-coverage/traces/
docker exec -i eos-mgm-test ls -lh /eos-coverage/traces/

docker exec -i eos-mgm-test cp /eos-coverage/coverage-base.info /eos-coverage/coverage-final-unfiltered.info
for container in "${CONTAINERS[@]}"; do
  echo "Merging $container.info"
  docker exec -i eos-mgm-test /bin/bash -c 'lcov --quiet --add-tracefile /eos-coverage/coverage-final-unfiltered.info --add-tracefile /eos-coverage/traces/'$container'.info --config-file /eos-coverage/eoslcov.rc --output-file /eos-coverage/coverage-final-unfiltered.info'
done

docker exec -i eos-mgm-test lcov --summary /eos-coverage/coverage-final-unfiltered.info --config-file /eos-coverage/eoslcov.rc
rm -rf /tmp/eos-coverage-traces/

#------------------------------------------------------------------------------
print_header "Filter coverage file"

# Figure out the namespace type to exclude
EXCLUDE_NAMESPACE=ns_in_memory
if $(docker exec -i eos-mgm-test grep /etc/xrd.cf.mgm -e "^mgmofs.nslib" | grep -q NsInMemory ) ; then
  EXCLUDE_NAMESPACE=ns_quarkdb
fi

docker exec -i eos-mgm-test lcov --remove /eos-coverage/coverage-final-unfiltered.info \
  "${SRCPATH}/test.pb.h" \
  "${SRCPATH}/auth_plugin/tests/*" \
  "${SRCPATH}/build/*" \
  "${SRCPATH}/common/backward-cpp/*" \
  "${SRCPATH}/common/crc32c/*" \
  "${SRCPATH}/common/dbmaptest/*" \
  "${SRCPATH}/common/eos_cta_pb/*" \
  "${SRCPATH}/common/fmt/*" \
  "${SRCPATH}/common/mutextest/*" \
  "${SRCPATH}/common/ulib/*" \
  "${SRCPATH}/common/xrootd-ssi-protobuf-interface/*" \
  "${SRCPATH}/console/ConsoleCompletion.cc" \
  "${SRCPATH}/console/ConsolePipe.cc" \
  "${SRCPATH}/fst/io/rados/*" \
  "${SRCPATH}/fst/tests/*" \
  "${SRCPATH}/fuse/tests/*" \
  "${SRCPATH}/fusex/tests/*" \
  "${SRCPATH}/mq/tests/*" \
  "${SRCPATH}/sync/*" \
  "${SRCPATH}/test/*" \
  "${SRCPATH}/unit_tests/*" \
  "${SRCPATH}/namespace/*/tests/*" \
  "${SRCPATH}/namespace/${EXCLUDE_NAMESPACE}/*" \
  "${SRCPATH}/namespace/ns_quarkdb/qclient/test/*" \
  --config-file /eos-coverage/eoslcov.rc --output-file /eos-coverage/coverage-final.info

#------------------------------------------------------------------------------
print_header "Generating HTML report"
docker exec -i eos-mgm-test genhtml --output-directory /eos-coverage/coverage-report/ --title "EOS CI Coverage" --config-file /eos-coverage/eoslcov.rc --ignore-errors source /eos-coverage/coverage-final.info

#------------------------------------------------------------------------------
print_header "Exporting HTML report and trace files"
rm -rf eos-coverage/
mkdir -p eos-coverage/
docker cp eos-mgm-test:/eos-coverage/coverage-report/ eos-coverage/
docker cp eos-mgm-test:/eos-coverage/traces/ eos-coverage/
docker cp eos-mgm-test:/eos-coverage/coverage-final-unfiltered.info eos-coverage/
docker cp eos-mgm-test:/eos-coverage/coverage-final.info eos-coverage/
ls -lh eos-coverage/

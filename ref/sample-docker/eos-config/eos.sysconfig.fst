# ----------------------------------------------------------------------
# File: eos.example
# Author: Andreas-Joachim Peters - CERN
# ----------------------------------------------------------------------

# ************************************************************************
# * EOS - the CERN Disk Storage System                                   *
# * Copyright (C) 2011 CERN/Switzerland                                  *
# *                                                                      *
# * This program is free software: you can redistribute it and/or modify *
# * it under the terms of the GNU General Public License as published by *
# * the Free Software Foundation, either version 3 of the License, or    *
# * (at your option) any later version.                                  *
# *                                                                      *
# * This program is distributed in the hope that it will be useful,      *
# * but WITHOUT ANY WARRANTY; without even the implied warranty of       *
# * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the        *
# * GNU General Public License for more details.                         *
# *                                                                      *
# * You should have received a copy of the GNU General Public License    *
# * along with this program.  If not, see <http://www.gnu.org/licenses/>.*
# ************************************************************************

# Should we run with another limit on the core file size other than the default?
DAEMON_COREFILE_LIMIT=unlimited

# Disable the KRB5 replay cache
export KRB5RCACHETYPE=none

# What roles should the xroot daemon run for. For each role you can overwrite
# the default options using a dedicate sysconfig file
# e.g. /etc/sysconfig/xrd.<role>. The role based mechanism allows for
# multiple xrd's running with different options to be controlled via
# the same initd script

XRD_ROLES="fst"

# ------------------------------------------------------------------
# EOS Configuration
# ------------------------------------------------------------------

# User std::shared_timed_mutex instead of the pthread_rwlock_*
export EOS_USE_SHARED_MUTEX=1

# The EOS instance name
export EOS_INSTANCE_NAME=eostestatcf

# The EOS configuration to load after daemon start
export EOS_AUTOLOAD_CONFIG=default

# The EOS broker URL 
export EOS_BROKER_URL=root://eos-mgm-kisti01.sdfarm.kr:1097//eos/

# The EOS host geo location tag used to sort hosts into geographical (rack) locations 
export EOS_GEOTAG="kisti::gsdc::d10"

# The fully qualified hostname of MGM master1
export EOS_MGM_MASTER1=eos-mgm-kisti01.sdfarm.kr

# The fully qualified hostname of MGM master2
export EOS_MGM_MASTER2=eos-mgm-kisti02.sdfarm.kr

# The alias which selects master 1 or 2
export EOS_MGM_ALIAS=eos-mgm-kisti.sdfarm.kr

# The mail notification in case of fail-over
export EOS_MAIL_CC="sahn@kisti.re.kr"
#export EOS_NOTIFY="mail -s `date +%s`-`hostname`-eos-notify $EOS_MAIL_CC"

# Enable core dumps initiated internally 
#export EOS_CORE_DUMP

# Disable shutdown/signal handlers for debugging
#export EOS_NO_SHUTDOWN

#-------------------------------------------------------------------------------
# FST Configuration
#-------------------------------------------------------------------------------

# Stream timeout for operations
#export EOS_FST_STREAM_TIMEOUT=300

# Number of threads for transfer operations (Balance, Drain or Transfer actions)
export EOS_FST_TRANSFER_THREAD_POOL=20

#-------------------------------------------------------------------------------
# FST External Storage Configuration
#-------------------------------------------------------------------------------

# Set number of connection retries
export EOS_FST_CONNECTION_RETRY=1

# Set S3 access credentials
#export EOS_FST_S3_ACCESS_KEY=""
#export EOS_FST_S3_SECRET_KEY=""

# Set S3 theoretical storage size
export EOS_FST_S3_STORAGE_SIZE=20000000000

# Set HTTPS X509 certificate path
#export EOS_FST_HTTPS_X509_CERTIFICATE_PATH=""

# ------------------------------------------------------------------
# FUSE Configuration
# ------------------------------------------------------------------

# The mount directory for 'eosd' 
export EOS_FUSE_MOUNTDIR=/eos/

# The MGM host from where to do the initial mount
export EOS_FUSE_MGM_ALIAS=eos-mgm-kisti01.sdfarm.kr

# Enable FUSE debugging mode (default off)
#export EOS_FUSE_DEBUG=1

# Disable parallel IO mode (default on)
#export EOS_FUSE_NOPIO=1

# Disable multi-threading in FUSE (default on)
#export EOS_FUSE_NO_MT=1

# ------------------------------------------------------------------
# HTTPD Configuration
# ------------------------------------------------------------------
# Enable multi-threaded httpd
export EOS_HTTP_THREADPOOL="epoll"
export EOS_HTTP_THREADPOOL_SIZE=16

# ------------------------------------------------------------------
# Federation Configuration
# ------------------------------------------------------------------

# The host[:port] name of the meta manager (global redirector)
#export EOS_FED_MANAGER=eos.cern.ch:1094

# The port of the PSS xrootd server
#export EOS_PSS_PORT=1098

# The hostname[:port] of the EOS MGM service
#export EOS_PSS_MGM=$EOS_MGM_ALIAS:1094

# The path which should be proxied (/ for all)
#export EOS_PSS_PATH=/

# ------------------------------------------------------------------
# Test Configuration
# ------------------------------------------------------------------

# mail notification for failed tests
#export EOS_TEST_MAILNOTIFY=apeters@mail.cern.ch

# SMS notification for failed tests
#export EOS_TEST_GSMNOTIFY="0041764875002@mail2sms.cern.ch"

# Instance name = name of directory at deepness 2 /eos/<instance>/
#export EOS_TEST_INSTANCE="dev"

# MGM host redirector
#export EOS_TEST_REDIRECTOR=eostest.cern.ch

# local test output directory
#export EOS_TEST_TESTSYS=/tmp/eos-instance-test

# time to lock re-sending of SMS for consecutively failing tests
#export EOS_TEST_GSMLOCKTIME=3600

# max. time given to the test to finish
#export EOS_TEST_TESTTIMESLICE=300

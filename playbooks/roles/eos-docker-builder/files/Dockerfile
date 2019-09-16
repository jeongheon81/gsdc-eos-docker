#
# Simple EOS Docker file
#
# Version 0.2

FROM centos:7
MAINTAINER Elvin Sindrilaru, esindril@cern.ch, CERN 2017

# Add extra repositories
ADD repos/*.repo /etc/yum.repos.d/

# Add helper scripts
ADD image_scripts/*.sh /
RUN chmod a+x *.sh

# Add configuration files for EOS instance
#ADD configs/eos.sysconfig /etc/sysconfig/eos
#ADD configs/xrd.cf.* configs/krb5.conf /etc/
ADD configs/fuse.conf /etc/eos/fuse.conf
ADD dictionary/fstfmd.dict /var/eos/md/

# Add configuration files for forwarding proxy server
ADD configs/xrootd.conf /etc/tmpfiles.d/
ADD configs/xrootd-fwd-proxy.cfg /etc/xrootd/

RUN mkdir -p /var/tmp/eosxd-cache/ /var/tmp/eosxd-journal/ /data/
RUN useradd eos-user

# Docker will aggressively cache the following command, but this is fine, since
# these packages are not updated often.
RUN yum -y --nogpg install \
    heimdal-server heimdal-workstation \
    krb5-workstation yum-plugin-priorities \
    createrepo initscripts less nano \
    git parallel compat-libf2c-34 libgfortran \
    gdb gcc-c++ cmake3 libacl-devel perl-Test-Harness \
    rpm-build bzip2 automake autoconf libtool sudo vim \
    centos-release-scl-rh at

# Install new EOS from created repo - the ADD command will reset the docker cache,
# and any commands after that point will be uncached.
#ENV EOSREPODIR="/repo/eos"
#ADD cc7_artifacts ${EOSREPODIR}

# Special packages, must be installed un-cached.
#RUN createrepo ${EOSREPODIR}; \
#    echo -e "[eos-artifacts]\nname=EOS artifacts\nbaseurl=file://${EOSREPODIR}\ngpgcheck=0\nenabled=1\npriority=1" >> /etc/yum.repos.d/eos.repo; \
RUN yum -y --nogpg install quarkdb quarkdb-debuginfo redis grid-hammer davix; \
    yum -y --nogpg install \
    eos-server eos-testkeytab eos-archive eos-client \
    eos-debuginfo eos-fuse eos-fusex eos-test xrootd xrootd-client

# Generate a new forwardable keytab 'eos-test+' to replace the not-forwardable one (installed by the eos-testkeytab package).
# This is useful to deploy EOS on Kubernetes clusters running on CERN's Cloud Infrastructure; you can remove these lines if you don't need one.
RUN yes | xrdsssadmin -k eos-test del /etc/eos.keytab; \
    yes | xrdsssadmin -u daemon -g daemon -k eos-test+ -n 1234567890123456789 add /etc/eos.keytab; \
    chown daemon:daemon /etc/eos.keytab

# Change owner of /var/spool/xrootd directory to daemon
RUN chown daemon:daemon /var/spool/xrootd

ENTRYPOINT ["/bin/bash"]

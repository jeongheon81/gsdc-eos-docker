#
# Simple EOS Docker file
#
# Version 0.2

FROM centos:7
MAINTAINER Elvin Sindrilaru, esindril@cern.ch, CERN 2017

# Add extra repositories
ADD repos/*.repo /etc/yum.repos.d/

# Add helper scripts
#ADD image_scripts/*.sh /
#RUN chmod a+x *.sh

# Add configuration files for EOS instance
#ADD configs/eos.sysconfig /etc/sysconfig/eos
#ADD configs/xrd.cf.* configs/krb5.conf /etc/
ADD configs/fuse.conf /etc/eos/fuse.conf
ADD dictionary/fstfmd.dict /var/eos/md/

# Add configuration files for forwarding proxy server
ADD configs/xrootd.conf /etc/tmpfiles.d/
ADD configs/xrootd-fwd-proxy.cfg /etc/xrootd/

RUN mkdir -p /var/tmp/eosxd-cache/ /var/tmp/eosxd-journal/ /data/ /var/spool/eos/core
RUN useradd eos-user

# Docker will aggressively cache the following command, but this is fine, since
# these packages are not updated often.
RUN rpm --rebuilddb && yum -y install \
    heimdal-server heimdal-workstation \
    krb5-workstation yum-plugin-priorities \
    createrepo initscripts less nano \
    git parallel compat-libf2c-34 libgfortran \
    gdb gcc-c++ cmake3 libacl-devel perl-Test-Harness \
    rpm-build bzip2 automake autoconf libtool sudo vim \
    centos-release-scl-rh at \ 
    protobuf3 cryptsetup e2fsprogs xfsprogs smartmontools \
    wget bind-utils && \
    yum clean all && \
    rm -rf /var/cache/yum

# Install new EOS from created repo - the ADD command will reset the docker cache,
# and any commands after that point will be uncached.
# ENV EOSREPODIR="/repo/eos"
# ADD cc7_artifacts ${EOSREPODIR}

# Special packages, must be installed un-cached.
# RUN createrepo ${EOSREPODIR}; \
#     echo -e "[eos-artifacts]\nname=EOS artifacts\nbaseurl=file://${EOSREPODIR}\ngpgcheck=0\nenabled=1\npriority=1" >> /etc/yum.repos.d/eos.repo; \
RUN rpm --rebuilddb && \
    yum -y --nogpg install quarkdb quarkdb-debuginfo redis grid-hammer davix && \
    yum -y --nogpg install \
    eos-server eos-testkeytab eos-archive eos-client \
    eos-debuginfo eos-fuse eos-fusex eos-test eos-ns-inspect \
    xrootd-client && \
    yum clean all && \
    rm -rf /var/cache/yum

    # xrootd xrootd-libs xrootd-client xrootd-client-libs xrootd-client-devel \
    # xrootd-server xrootd-server-libs xrootd-server-devel xrootd-private-devel; \

# *************
# NOTE: !UGLY!*
# *************
# This is an ugly hack but the FST ofs.tpc config requires /usr/bin/xrdcp
# and this is provided by the xrootd-client package. With EOS having eos-xrootd
# as dependency the xrdcp program is in /opt/eos/xrootd/bin/xrdcp and the
# xrootd-client package is no longer installed and therefore starting the FSTs
# fails. This only happens on CC7.
#RUN yum install -y --nogpg install xrootd-client


# Generate a new forwardable keytab 'eos-test+' to replace the not-forwardable one (installed by the eos-testkeytab package).
# This is useful to deploy EOS on Kubernetes clusters running on CERN's Cloud Infrastructure; you can remove these lines if you don't need one.
RUN yes | xrdsssadmin -k eos-test del /etc/eos.keytab; \
    yes | xrdsssadmin -u daemon -g daemon -k eos-test+ -n 1234567890123456789 add /etc/eos.keytab; \
    chown daemon:daemon /etc/eos.keytab

# Change owner of /var/spool/xrootd directory to daemon
RUN chown daemon:daemon /var/spool/xrootd; \
    chown daemon:daemon /var/spool/eos; \
    chown daemon:daemon /var/spool/eos/core; \
    chown daemon:daemon /var/eos/md; \
    chown daemon:daemon /var/eos/md/fstfmd.dict; \
    chmod 0700 /var/eos/md

# Raise limits
RUN echo "*          soft    nofile    200000" >> /etc/security/limits.d/10-nofile.conf && \
    echo "*          hard    nofile    200000" >> /etc/security/limits.d/10-nofile.conf

# ENTRYPOINT ["/bin/bash"]


RUN wget -O /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.2/dumb-init_1.2.2_x86_64 && \
    chmod +x /usr/local/bin/dumb-init

ADD image_scripts/*docker-entrypoint.sh /usr/local/bin/
RUN chmod a+x /usr/local/bin/*.sh

# ENTRYPOINT ["/usr/local/bin/dumb-init", "--", "/usr/local/bin/docker-entrypoint.sh"]
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

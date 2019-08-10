#
# EOS Docker file for production using eos-docker-utils
#
# Version 0.1

FROM centos/systemd
LABEL maintainer="martin.vala@cern.ch"

RUN yum install --nogpg -y epel-release createrepo

# Exclude xrootd from epel
RUN sed -i '/^enabled=.*/a exclude=xrootd*' /etc/yum.repos.d/epel.repo

# Add required repositories
RUN curl http://repository.egi.eu/sw/production/cas/1/current/repo-files/EGI-trustanchors.repo -o /etc/yum.repos.d/lcg-CA.repo

# Add this repo for EOS dependencies
ADD eos-docker/eos.repo /etc/yum.repos.d/

# Install new EOS from created repo - the ADD command will reset the docker cache,
# and any commands after that point will be uncached.
ENV EOSREPODIR="/repo/eos"
ADD cc7_artifacts ${EOSREPODIR}
RUN createrepo ${EOSREPODIR}; \
    echo -e "[eos-artifacts]\nname=EOS artifacts\nbaseurl=file://${EOSREPODIR}\ngpgcheck=0\nenabled=1\npriority=1" >> /etc/yum.repos.d/eos-ci.repo;

# Instal XRootD
RUN yum -y --nogpg update; \
    yum -y --nogpg install \
    net-tools nmap mc krb5-workstation \
    nss-pam-ldapd authconfig smartmontools \
    initscripts sysvinit-tools less logrotate \
    xrootd \
    xrootd-client \
    xrootd-client-libs \
    xrootd-libs \
    xrootd-server-devel \
    xrootd-server-libs \
    quarkdb eos-nginx \
    xrootd-alicetokenacc eos-apmon lcg-CA; \
    yum -y --nogpg install eos-server --disablerepo="eos"

RUN if [ -e /etc/grid-security/certificates/nginx-bundle.pem ]; then rm -rf /etc/grid-security/certificates/nginx-bundle.pem; fi
RUN mkdir -p /etc/grid-security/certificates/
RUN if ls /etc/grid-security/certificates/*.pem 1> /dev/null 2>&1; then cat /etc/grid-security/certificates/*.pem > /etc/grid-security/certificates/nginx-bundle.pem; fi

RUN systemctl disable eos
RUN systemctl disable eosapmond

ADD eos-docker/projects/eos/docker/eos-docker-config-gen /usr/bin/eos-docker-config-gen 
ADD eos-docker/projects/eos/docker/eos-docker-env.sh /etc/profile.d/eos-docker.sh
#ADD eos-docker/projects/eos/utils/eos-docker.cf.default /etc/eos-docker/eos-docker.cf.default
ADD eos-docker/projects/eos/docker/eos-docker-export /usr/bin/eos-docker-export
ADD eos-docker/projects/eos/docker/eos-docker-mgm-init /usr/bin/eos-docker-mgm-init

# Clean yum cache
RUN yum clean all
    
CMD ["/usr/sbin/init"]

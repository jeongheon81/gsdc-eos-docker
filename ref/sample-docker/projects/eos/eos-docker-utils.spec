Name:           eos-docker-utils
Version:        1.0.20
Release:        1%{?dist}
Summary:        EOS docker utils
License:        LGPL v3+

Group:          System Environment/Base
URL:            http://eos.cern.ch
Source0:        http://eos.cern.ch/files/%{name}-%{version}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:      noarch

Requires: pssh

%description
EOS docker utils

%prep
%setup -q

%build
echo "Nothing to build"

%install
rm -rf $RPM_BUILD_ROOT

sed -i 's/^export ED_VERSION=.*/export ED_VERSION=%{version}/' utils/eos-docker
mkdir -p $RPM_BUILD_ROOT/%{_sysconfdir}/profile.d/
mv utils/eos-docker-env.sh $RPM_BUILD_ROOT/%{_sysconfdir}/profile.d/eos-docker.sh
mkdir -p $RPM_BUILD_ROOT/%{_sysconfdir}/eos-docker
mv utils/eos-docker.cf.default $RPM_BUILD_ROOT/%{_sysconfdir}/eos-docker
mkdir -p $RPM_BUILD_ROOT/%{_bindir}
mv utils/* $RPM_BUILD_ROOT/%{_bindir}/


%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%{_bindir}/*
%{_sysconfdir}/profile.d/*
%{_sysconfdir}/eos-docker/*

%changelog

Name:		valid
Version:	0.3
Release:	1%{?dist}
Summary:	Image validation (threaded) server

Group:		Development/Python
License:	GPLv3+
URL:		https://github.com/RedHatQE/valid
Source0:	%{name}-%{version}.tar.gz
BuildRoot:	%(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
BuildArch:  noarch

BuildRequires:	python-devel
Requires:	python-patchwork python-paramiko PyYAML

%description
Cloud image validation suite

%package client
Group:		Development/Python
Summary:	Image validation (threaded) client
Requires: PyYAML

%description client
Cloud image validation suite

%prep
%setup -q

%build

%install
%{__python} setup.py install -O1 --root $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT%{_sharedstatedir}/valid

%clean
rm -rf $RPM_BUILD_ROOT

%pre
getent group valid >/dev/null || groupadd -r valid
getent passwd valid >/dev/null || \
useradd -r -g valid -d /var/lib/valid -s /sbin/nologin \
        -c "Validation user" valid
        exit 0

%files
%defattr(-,root,root,-)
%doc LICENSE README.md
%attr(0755, root, root) %{_bindir}/valid_runner.py
%attr(0755, root, root) %{_bindir}/valid_bugzilla_reporter.py
%attr(0755, root, root) %{_bindir}/valid_cert_creator.py
%attr(0755, root, root) %{_bindir}/valid_debug_run.py
%dir %{_sysconfdir}/valid
%config(noreplace) %attr(0640, root, valid) %{_sysconfdir}/validation.yaml
%config(noreplace) %attr(0644, root, valid) %{_sysconfdir}/valid/setup_script.sh
%{python_sitelib}/*.egg-info
%{python_sitelib}/valid/*
%{_datadir}/%name
%attr(0775, valid, valid) %{_sharedstatedir}/valid

%files client
%attr(0755, root, root) %{_bindir}/valid_client.py

%changelog
* Mon Dec 17 2012 Vitaly Kuznetsov <vitty@redhat.com> 0.3-1
- new version
* Wed Dec 05 2012 Vitaly Kuznetsov <vitty@redhat.com> 0.2-1
- new package built with tito


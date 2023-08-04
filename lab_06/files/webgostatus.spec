Name:           webgostatus
Version:        1.0
Release:        1%{?dist}
Summary:        Status web server

License:        MIT
URL:            https://github.com/0rps/otus-linux-adm/tree/main/lab_06
Source0:        webgostatus-%{version}.tar.gz

BuildRequires:  golang
BuildRequires:  make


%description
Simple HTTP server that returns HTTP response with code "200".


%global debug_package %{nil}


%prep
%autosetup


%build
make


%install
%make_install


%files
/usr/bin/webgostatus


%changelog
* Sun Jul 30 2023 Test User testuser@test.com - 1.0.0
- Initial version

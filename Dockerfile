FROM registry.access.redhat.com/rhel7/rhel
MAINTAINER AttackIQ, Inc. <info@attackiq.com>

### Atomic/OpenShift Labels - https://github.com/projectatomic/ContainerApplicationGenericLabels
LABEL name="attackiq/firedrill-server" \
      maintainer="info@attackiq.com" \
      vendor="AttackIQ, Inc." \
      version="2.6" \
      release="27" \
      summary="AttackIQ FireDrill Server" \
      description="Industry's first live IT accountability platform that continuously challenges your security assumptions, providing qualtifiable data to accurately protect, detect, and respond to cybersecurity threats."

### Atomic Help File - Write in Markdown, it will be converted to man format at build time.
### https://github.com/projectatomic/container-best-practices/blob/master/creating/help.adoc
#COPY help.md /tmp/

# Required by rhc4tp
COPY licenses /licenses

### Install additional repos
RUN yum -y install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
    yum -y install -y https://download.postgresql.org/pub/repos/yum/9.6/redhat/rhel-7-x86_64/pgdg-redhat96-9.6-3.noarch.rpm

### Add necessary Red Hat repos here
RUN REPOLIST=rhel-7-server-rpms,rhel-7-server-extras-rpms,rhel-7-server-optional-rpms,epel,pgdg96 \
# Install dependencies:
# git - required by the happy-api python package
# libxml2-dev libxslt-dev lib32z1-dev libpq-dev libsasl2-dev libldap2-dev libssl-dev libffi-dev unzip zip - required libraries
# python-pip python-virtualenv python-dev python-lxml python-setuptools - python dependencies
# mono-devel nsis - used for building agent installers
# ntpdate ntp - to keep time up to date
# supervisor - used to run uWSGI, celery workers, celery beat
    INSTALL_PKGS="wget git gcc glibc-devel.i686 glibc-devel make automake gcc-c++ kernel-devel openssl-devel \
                  openldap-devel libxml2-devel libxslt-devel ntpdate ntp unzip postgresql-libs postgresql96-server \
                  python-virtualenv python-devel python-lxml python-setuptools python-psycopg2 supervisor firewalld \
                  fabric python-pip python2-pip mono-devel mingw32-nsis supervisor redis golang-github-cpuguy83-go-md2man" && \
    yum -y update-minimal --disablerepo "*" --enablerepo rhel-7-server-rpms --setopt=tsflags=nodocs \
      --security --sec-severity=Important --sec-severity=Critical && \
    yum -y install --disablerepo "*" --enablerepo ${REPOLIST} --setopt=tsflags=nodocs ${INSTALL_PKGS} && \
### help file markdown to man conversion
 #   go-md2man -in /tmp/help.md -out /help.1 && \
 # yum clean all

### Install Python dependencies
RUN pip install --upgrade pip setuptools



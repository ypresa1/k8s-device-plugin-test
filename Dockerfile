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

COPY system/docker/redhat/firedrill/etc /etc
COPY 3rdparty/phantomjs/phantomjs /usr/bin/
COPY 3rdparty/phantomjs/phantomjs /usr/lib/phantomjs/
RUN chmod +x /usr/bin/phantomjs && \
    chmod +x /usr/lib/phantomjs/phantomjs && \
    ln -s /usr/bin/uwsgi /usr/local/bin/uwsgi

### Setup user for build execution and application runtime
ENV APP_ROOT=/opt/attackiq/firedrill-server \
    APP_ETC=/var/lib/attackiq \
    USER_NAME=firedrill \
    USER_UID=10001
ENV LOG_DIR=${APP_ETC}/logs \
    DOWNLOADS_DIR=${APP_ETC}/downloads \
    DOWNLOADS_AIQ_DIR=${APP_ETC}/downloads_attackiq
RUN mkdir -p ${APP_ROOT} && chmod -R u+x ${APP_ROOT} && \
    mkdir -p ${APP_ETC} && chmod -R u+x ${APP_ETC} && \
    useradd -l -u ${USER_UID} -r -g 0 -d ${APP_ROOT} -s /sbin/nologin -c "${USER_NAME} user" ${USER_NAME} && \
    usermod -aG wheel ${USER_NAME} && \
    chown -R ${USER_NAME}:wheel ${APP_ROOT} && \
    chmod -R g=u ${APP_ROOT} && \
    chown -R ${USER_NAME}:wheel ${APP_ETC} && \
    chmod -R g=u ${APP_ETC} && \
    mkdir -p ${APP_ROOT}/system/docker/firedrill && \
    mkdir -p /usr/lib/phantomjs && \
    mkdir -p ${LOG_DIR} && \
    mkdir -p ${DOWNLOADS_DIR} && \
    mkdir -p ${DOWNLOADS_DIR} && \
    touch ${APP_ROOT}/.ai_build

WORKDIR ${APP_ROOT}

# Using a dynamic ARG here so we always invalidate the Docker cache and re-build the below layers (since they could change based on git branch).
# References: https://stackoverflow.com/questions/31782220/how-can-i-prevent-a-dockerfile-instruction-from-being-cached, https://github.com/moby/moby/issues/22832
# Have to set a value here so it will always change
ARG CACHE_BUILD
# first usage of the ARG will invalidate the cache - https://github.com/moby/moby/issues/20136
RUN echo $CACHE_BUILD

### Install Python dependencies
RUN pip install --upgrade pip setuptools
COPY requirements.txt .
RUN pip install -r requirements.txt

### Containers should NOT run as root as a good practice
USER 10001

### Copy required files
COPY system/docker/redhat/firedrill/*.ini system/docker/firedrill/
COPY system/docker/redhat/celerybeat system/docker/celerybeat
COPY system/docker/redhat/celeryworker system/docker/celeryworker
COPY dogstatsd_plugin.so .
COPY licenses licenses
COPY community community
COPY error-pages error-pages
COPY update-page update-page

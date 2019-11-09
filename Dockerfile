FROM ubuntu:19.10

MAINTAINER Min Kim <minskim@pkgsrc.org>

RUN adduser --disabled-login pbulk

RUN \
  apt-get update && \
  apt-get install -y \
    bsd-mailx \
    clang \
    curl \
    libssl-dev \
    locales \
    tzdata

ENV LC_ALL en_US.UTF-8
RUN locale-gen en_US.UTF-8

COPY pbulk.sh /

RUN \
  curl -L https://api.github.com/repos/NetBSD/pkgsrc/tarball/${gitref} | \
    tar -zxf - -C /usr && \
  mv /usr/NetBSD-pkgsrc-* /usr/pkgsrc && \
  cd /usr/pkgsrc/mk/pbulk && \
  env SH=/bin/bash sh /pbulk.sh -n && \
  cd / && rm -rf /usr/pkgsrc

RUN \
  echo 'bootstrapkit=/mnt/packages/bootstrap.tar.gz' >> /usr/pbulk/etc/pbulk.conf && \
  echo 'limited_list=/usr/pbulk/etc/pbulk.list' >> /usr/pbulk/etc/pbulk.conf && \
  echo 'make=/usr/pkg/bin/bmake' >> /usr/pbulk/etc/pbulk.conf && \
  echo 'pkgdb=/usr/pkg/pkgdb' >> /usr/pbulk/etc/pbulk.conf && \
  echo 'reuse_scan_results=no' >> /usr/pbulk/etc/pbulk.conf && \
  echo 'skip_age_check=yes' >> /usr/pbulk/etc/pbulk.conf

ENV \
  WRKOBJDIR=/tmp

COPY pbulk.list /usr/pbulk/etc

CMD /usr/pbulk/bin/bulkbuild

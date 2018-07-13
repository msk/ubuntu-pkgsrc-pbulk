FROM ubuntu:18.04

MAINTAINER Min Kim <minskim@pkgsrc.org>

RUN adduser --disabled-login pbulk

RUN \
  apt-get update && \
  apt-get install -y \
    curl \
    g++

RUN \
  curl -L https://api.github.com/repos/NetBSD/pkgsrc/tarball/${gitref} | \
    tar -zxf - -C /usr && \
  mv /usr/NetBSD-pkgsrc-* /usr/pkgsrc && \
  cd /usr/pkgsrc/mk/pbulk && env SH=/bin/bash sh ./pbulk.sh -n && \
  cd / && rm -rf /usr/pkgsrc

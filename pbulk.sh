#!/bin/sh
# $NetBSD: pbulk.sh,v 1.7 2018/02/08 12:59:28 triaxx Exp $
set -e

usage="usage: ${0##*/} [-lun] [-c mk.conf.fragment] [-d nodes]"

while getopts lunc:d: opt; do
    case $opt in
	l) limited=yes;;
	u) unprivileged=yes;;
	n) native=yes;;
	c) mk_fragment="${OPTARG}";;
	d) nodes="${OPTARG}";;
	\?) echo "$usage" 1>&2; exit 1;;
    esac
done
shift $(expr $OPTIND - 1)
if [ $# != 0 ]; then echo "$usage" 1>&2; exit 1; fi

: ${TMPDIR:=/tmp}

## settings for unprivileged build:
if [ -n "$unprivileged" ]; then
: ${PBULKPREFIX:=${HOME}/pbulk}
: ${PKGSRCDIR:=${HOME}/pkgsrc}
: ${PREFIX:=${HOME}/pkg}
: ${PACKAGES:=${HOME}/packages}
: ${BULKLOG:=${HOME}/bulklog}
fi

##
: ${PBULKPREFIX:=/usr/pbulk}
: ${PBULKWORK:=${TMPDIR}/work-pbulk}

: ${PACKAGES:=/mnt/packages}
: ${BULKLOG:=/mnt/bulklog}

# almost constant:
: ${PKGSRCDIR:=/usr/pkgsrc}

# setting pkgdb directory:
if [ -n "$unprivileged" -o -n "${PREFIX}" ]; then
: ${PKGDBDIR:=${PREFIX}/var/db/pkg} 
fi

# Do it early since adding it after it fails is problematic:
if [ ! -n "$unprivileged" ]; then
case "$(uname)" in
NetBSD)
if ! id pbulk; then user add -m -g users pbulk; fi
;;
FreeBSD)
if ! id pbulk; then
    if ! pw groupshow users; then pw groupadd users; fi
    pw useradd pbulk -m -g users
fi
;;
*)
if ! id pbulk; then echo "user \"pbulk\" is absent"; exit 1; fi
;;
esac
fi

# Deploying pbulk packages:
# - bootstrapping
cat >${TMPDIR}/pbulk.mk <<EOF
PKG_DEVELOPER=	yes

TOOLS_PLATFORM.mail?=	/usr/bin/bsd-mailx
EOF

env CC=clang ${PKGSRCDIR}/bootstrap/bootstrap \
  ${unprivileged:+--unprivileged} \
  --compiler=clang \
  --mk-fragment=${TMPDIR}/pbulk.mk \
  --prefix=${PBULKPREFIX} \
  --workdir=${PBULKWORK}
rm -rf ${PBULKWORK}
rm -f ${TMPDIR}/pbulk.mk

# - installing pbulk
(cd ${PKGSRCDIR}/pkgtools/pbulk && PACKAGES=${TMPDIR}/packages-pbulk WRKOBJDIR=${TMPDIR}/obj-pbulk ${PBULKPREFIX}/bin/bmake install)
rm -rf ${TMPDIR}/obj-pbulk
rm -rf ${TMPDIR}/packages-pbulk

## cleaning after all this:
# rm -rf ${PBULKPREFIX}

cat >> ${PBULKPREFIX}/etc/pbulk.conf.over <<EOF
#
# Overriding default settings:
master_mode=no
bootstrapkit=${PACKAGES}/bootstrap.tar.gz
bulklog=${BULKLOG}
packages=${PACKAGES}
mail=:
rsync=:
EOF
# base_url needs to be adjusted, although the pbulk code should
# not need to know it at all, maybe except for generating the
# mail that the report has been completed.

# Speed scan phase up for repeated runs:
cat >> ${PBULKPREFIX}/etc/pbulk.conf.over <<EOF
reuse_scan_results=yes
EOF

# Quotes around "EOF" are important below
# (they prevent variable expansion in here-document):
cat >> ${PBULKPREFIX}/etc/pbulk.conf.over <<"EOF"
# Don't forget to recompute dependent settings:
loc=${bulklog}/meta
EOF

if [ -n "$limited" ]; then
cat >> ${PBULKPREFIX}/etc/pbulk.conf.over <<EOF
# Limited list build overrides:
limited_list=${PBULKPREFIX}/etc/pbulk.list
EOF

# generate minimal list
cat > ${PBULKPREFIX}/etc/pbulk.list <<EOF
pkgtools/digest
EOF
fi

if [ -n "$unprivileged" ]; then
# Unprivileged bulk build:
cat >> ${PBULKPREFIX}/etc/pbulk.conf.over <<EOF
# Unprivileged bulk build overrides:
unprivileged_user=$(id -un)
pkgsrc=${PKGSRCDIR}
prefix=${PREFIX}
varbase=${PREFIX}/var
pkgdb=${PKGDBDIR}
EOF
elif [ -n "${PREFIX}" ]; then
# Non-default prefix:
cat >> ${PBULKPREFIX}/etc/pbulk.conf.over <<EOF
# Non-default prefix overrides:
prefix=${PREFIX}
varbase=${PREFIX}/var
pkgdb=${PKGDBDIR}
EOF
fi

# Quotes around "EOF" are important below
# (they prevent variable expansion in here-document):
cat >> ${PBULKPREFIX}/etc/pbulk.conf.over <<"EOF"
# Don't forget to recompute dependent settings:
make=${prefix}/bin/bmake
EOF

if [ -n "$native" ]; then
# Native bulk build (native make, no bootstrap kit needed):
cat >> ${PBULKPREFIX}/etc/pbulk.conf.over <<EOF
# Native bulk build overrides:
make=/usr/bin/make
bootstrapkit=
EOF
fi

cat ${PBULKPREFIX}/etc/pbulk.conf ${PBULKPREFIX}/etc/pbulk.conf.over > ${PBULKPREFIX}/etc/pbulk.conf.new
cp ${PBULKPREFIX}/etc/pbulk.conf ${PBULKPREFIX}/etc/pbulk.conf.bak
mv ${PBULKPREFIX}/etc/pbulk.conf.new ${PBULKPREFIX}/etc/pbulk.conf

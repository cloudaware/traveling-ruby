#!/bin/bash
set -e
SELFDIR=`dirname "$0"`
SELFDIR=`cd "$SELFDIR" && pwd`
source "$SELFDIR/../shared/library.sh"

# Builds a pinned OpenSSL with the UCRT64 toolchain, for build-ruby.sh to use
# through OPENSSL_DIR. MSYS2 only packages the latest OpenSSL, so an LTS line
# has to be built from source.

OPENSSL_VERSION=
PREFIX=
# Compiled-in OPENSSLDIR, where OpenSSL looks for openssl.cnf at runtime. It
# must not be writable by unprivileged users: the agent runs as SYSTEM, and a
# planted openssl.cnf can load arbitrary modules into it. The build also uses
# no-dso, so nothing is ever loaded from the compiled-in ENGINESDIR and
# MODULESDIR, which point into the build machine's MSYS2.
OPENSSLDIR="C:/Program Files/Cloudaware/Breeze/etc/ssl"

function usage()
{
	echo "Usage: ./build-openssl.sh [options] <VERSION> <PREFIX>"
	echo "Build OpenSSL from source with the UCRT64 toolchain."
	echo
	echo "Options:"
	echo "  -d DIR         Compiled-in OPENSSLDIR. Default: $OPENSSLDIR"
	echo "  -h             Show this help"
}

function parse_options()
{
	local OPTIND=1
	local opt
	while getopts "d:h" opt; do
		case "$opt" in
		d)
			OPENSSLDIR=$OPTARG
			;;
		h)
			usage
			exit
			;;
		*)
			return 1
			;;
		esac
	done

	(( OPTIND -= 1 )) || true
	shift $OPTIND || true
	OPENSSL_VERSION="$1"
	PREFIX="$2"

	if [[ "$OPENSSL_VERSION" = "" || "$PREFIX" = "" ]]; then
		usage
		exit 1
	fi
}

parse_options "$@"

if [[ -f "$PREFIX/bin/openssl.exe" ]] && "$PREFIX/bin/openssl.exe" version | grep -q "OpenSSL $OPENSSL_VERSION "; then
	echo "openssl-$OPENSSL_VERSION already installed in $PREFIX"
	exit
fi

export MSYSTEM=UCRT64
export PATH="/ucrt64/bin:$PATH"

WORK_DIR=`mktemp -d`
trap 'rm -rf "$WORK_DIR"' EXIT
cd "$WORK_DIR"

header "Downloading openssl-$OPENSSL_VERSION"
URL="https://github.com/openssl/openssl/releases/download/openssl-$OPENSSL_VERSION/openssl-$OPENSSL_VERSION.tar.gz"
run curl --fail -sSL -o "openssl-$OPENSSL_VERSION.tar.gz" "$URL"
run curl --fail -sSL -o "openssl-$OPENSSL_VERSION.tar.gz.sha256" "$URL.sha256"
EXPECTED_SHA=`awk '{print $1}' "openssl-$OPENSSL_VERSION.tar.gz.sha256"`
ACTUAL_SHA=`sha256sum "openssl-$OPENSSL_VERSION.tar.gz" | awk '{print $1}'`
if [[ "$EXPECTED_SHA" != "$ACTUAL_SHA" ]]; then
	echo "ERROR: sha256 mismatch for openssl-$OPENSSL_VERSION.tar.gz: $ACTUAL_SHA != $EXPECTED_SHA"
	exit 1
fi
run tar xzf "openssl-$OPENSSL_VERSION.tar.gz"

header "Building openssl-$OPENSSL_VERSION"
cd "openssl-$OPENSSL_VERSION"
run perl Configure mingw64 shared no-dso no-tests no-docs \
	--prefix="$PREFIX" --libdir=lib --openssldir="$OPENSSLDIR"
run make -j`nproc`
run make install_sw

run "$PREFIX/bin/openssl.exe" version -a

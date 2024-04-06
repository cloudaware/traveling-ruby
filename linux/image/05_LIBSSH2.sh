#!/usr/bin/env bash
set -e
# shellcheck source=linux/image/functions.sh
source /tr_build/functions.sh


LIBSSH2_VERSION=1.11.0
MAKE_CONCURRENCY=10
SKIP_LIBSSH2=${SKIP_LIBSSH2:-true}

### libssh2
if [[ $SKIP_LIBSSH2 != true ]]; then
	header "Installing libssh2"
	if [[ ! -e /hbb_shlib/lib/libssh2.a ]]; then
		download_and_extract libssh2-$LIBSSH2_VERSION.tar.gz \
			libssh2-$LIBSSH2_VERSION \
			http://www.libssh2.org/download/libssh2-$LIBSSH2_VERSION.tar.gz

		(
			source /hbb_shlib/activate
			export CFLAGS="$STATICLIB_CFLAGS"
			export CXXFLAGS="$STATICLIB_CXXFLAGS"
			unset LDFLAGS
			run ./configure --prefix=/hbb_shlib --enable-static --disable-shared \
				--with-openssl --with-libz --disable-examples-build --disable-debug
			run make -j$MAKE_CONCURRENCY
			run make install-strip -j$MAKE_CONCURRENCY
		)
		if [[ "$?" != 0 ]]; then false; fi

		echo "Leaving source directory"
		popd >/dev/null
		run rm -rf libssh2-$LIBSSH2_VERSION
	fi
fi

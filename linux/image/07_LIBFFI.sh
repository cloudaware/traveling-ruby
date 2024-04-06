#!/usr/bin/env bash
set -e
# shellcheck source=linux/image/functions.sh
source /tr_build/functions.sh

LIBFFI_VERSION=3.4.4
MAKE_CONCURRENCY=10

SKIP_LIBFFI=${SKIP_LIBFFI:-true}


# ### libffi

if [[ $SKIP_LIBFFI != true ]]; then
header "Installing libffi"
	if [[ ! -e /hbb_shlib/lib64/libffi.a ]]; then
		download_and_extract yaml-$LIBFFI_VERSION.tar.gz \
			libffi-$LIBFFI_VERSION \
			https://github.com/libffi/libffi/releases/download/v$LIBFFI_VERSION/libffi-$LIBFFI_VERSION.tar.gz

		(
			source /hbb_shlib/activate
			export CFLAGS="$STATICLIB_CFLAGS"
			export CXXFLAGS="$STATICLIB_CXXFLAGS"

			unset LDFLAGS
			header "libffi - configure"
			## This works for libffi, but fiddle has an error
			# run ./configure --prefix=/hbb_shlib  --enable-static --enable-portable-binary --enable-shared


			## trying out for fiddle
			run ./configure --prefix=/hbb_shlib -disable-shared --enable-static \
				--with-pic=yes --disable-dependency-tracking --disable-docs



			header "libffi - make"
			run make -j$MAKE_CONCURRENCY
			run ls
			header "libffi - install-strip"
			run make install-strip -j$MAKE_CONCURRENCY
			header "libffi - ls /hbb_shlib/lib and /hbb_shlib/lib64"
			run ls /hbb_shlib/lib/
			# run ls /hbb_shlib/lib64/
			header "libffi - strip --strip-debug"
			# run ar -qs /hbb_shlib/lib/libpq.a ./*.o
			# run strip --strip-debug /hbb_shlib/lib64/libffi.a
			# run strip --strip-debug /hbb_shlib/lib64/libffi.so
			# run strip --strip-debug /hbb_shlib/lib64/libffi.so.8
			# run strip --strip-debug /hbb_shlib/lib64/libffi.so.8.1.0
			header "libffi - ls /hbb_shlib/lib and /hbb_shlib/lib64"
			run ls /hbb_shlib/lib/
			# run ls /hbb_shlib/lib64/
		)
		if [[ "$?" != 0 ]]; then false; fi

		echo "Leaving source directory"
		popd >/dev/null
		# run rm -rf libffi-$LIBFFI_VERSION

	else
		echo "libffi-$LIBFFI_VERSION Already installed."
	fi
fi

#!/usr/bin/env bash
set -e
# shellcheck source=linux/image/functions.sh
source /tr_build/functions.sh


ICU_RELEASE_VERSION=74-1
ICU_FILE_VERSION=74_1

MAKE_CONCURRENCY=10
if [[ $ARCHITECTURE == "armv7l" ]]; then
	ARCHITECTURE_BITS=32
else
	ARCHITECTURE_BITS=64
fi
echo $ARCHITECTURE_BITS
SKIP_ICU=${SKIP_ICU:-true}

### ICU
if [[ $SKIP_ICU != true ]]; then
	header "Installing ICU"
	if [[ ! -e /hbb_shlib/lib/libicudata.a ]]; then
		download_and_extract icu4c-$ICU_FILE_VERSION-src.tgz \
			icu/source \
			https://github.com/unicode-org/icu/releases/download/release-$ICU_RELEASE_VERSION/icu4c-$ICU_FILE_VERSION-src.tgz

		(
			source /hbb_shlib/activate
			export CFLAGS="$STATICLIB_CFLAGS -DU_CHARSET_IS_UTF8=1 -DU_USING_ICU_NAMESPACE=0"
			export CXXFLAGS="$STATICLIB_CXXFLAGS -DU_CHARSET_IS_UTF8=1 -DU_USING_ICU_NAMESPACE=0"
			unset LDFLAGS
			if [ "$(uname -m)" = "x86_64" ]; then
				echo "detected processor"
				if grep -q "alpine" /etc/os-release; then
					echo "detected alpine"
					if file /bin/busybox | grep 32 >/dev/null; then
					echo "32 bit target"
						CONFIGURE_TARGET="i586-alpine-linux-musl --with-library-bits 32 --enable-64bit-libs false "
					fi
				elif grep -q "ubuntu" /etc/os-release; then
					echo "detected ubuntu"
					if file /bin/dash | grep 32 >/dev/null; then
					echo "32 bit target"
						CONFIGURE_TARGET="i386-linux-gnu --with-library-bits 32 --enable-64bit-libs false "
					fi
				fi
			elif [ "$(uname -m)" = "i686" ]; then
				CONFIGURE_TARGET="i386-linux-gnu --with-library-bits 32 --enable-64bit-libs false "
			fi
			run ./configure $CONFIGURE_TARGET--prefix=/hbb_shlib --disable-samples --disable-tests \
				--enable-static --disable-shared --with-library-bits=$ARCHITECTURE_BITS
			run make -j$MAKE_CONCURRENCY VERBOSE=1
			run make install -j$MAKE_CONCURRENCY
			run strip --strip-debug /hbb_shlib/lib/libicu*.a
		)
		if [[ "$?" != 0 ]]; then false; fi

		echo "Leaving source directory"
		popd >/dev/null
		run rm -rf icu
	fi
fi
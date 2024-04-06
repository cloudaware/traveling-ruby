#!/usr/bin/env bash
set -e
# shellcheck source=linux/image/functions.sh
source /tr_build/functions.sh

MYSQL_LIB_VERSION=6.1.9
POSTGRESQL_VERSION=15.5
ICU_RELEASE_VERSION=74-1
ICU_FILE_VERSION=74_1
LIBSSH2_VERSION=1.11.0
LIBFFI_VERSION=3.4.4
LIBYAML_VERSION=0.2.5
MAKE_CONCURRENCY=10
if [[ $ARCHITECTURE == "armv7l" ]]; then
	ARCHITECTURE_BITS=32
else
	ARCHITECTURE_BITS=64
fi
echo $ARCHITECTURE_BITS
SKIP_INITIALIZE=${SKIP_INITIALIZE:-true}
SKIP_MYSQL=${SKIP_MYSQL:-true}
SKIP_POSTGRESQL=${SKIP_POSTGRESQL:-true}
SKIP_ICU=${SKIP_ICU:-true}
SKIP_LIBSSH2=${SKIP_LIBSSH2:-true}
SKIP_LIBYAML=${SKIP_LIBYAML:-true}
SKIP_LIBFFI=${SKIP_LIBFFI:-true}
SKIP_CLEANUP=${SKIP_CLEANUP:-true}

### Install base software

if [[ $SKIP_INITIALIZE != true ]]; then
	echo "$ARCHITECTURE" >/ARCHITECTURE
	run apk add --no-cache wget sudo readline-dev ncurses-dev curl
	run mkdir -p /ccache
fi

### MySQL

header "Installing MySQL"
if [[ $SKIP_MYSQL != true ]]; then
	# install_openssl shlib
	# run mv /hbb_shlib/bin/openssl /hbb/bin/
	# run rm -f "/hbb_shlib/bin/openssl"
	if [[ ! -e /hbb_shlib/lib/libmysqlclient.a ]]; then
		download_and_extract mysql-connector-c-$MYSQL_LIB_VERSION-src.tar.gz \
			mysql-connector-c-$MYSQL_LIB_VERSION-src \
			https://dev.mysql.com/get/Downloads/Connector-C/mysql-connector-c-$MYSQL_LIB_VERSION-src.tar.gz

		(
			source /hbb_shlib/activate
			run cmake -DCMAKE_INSTALL_PREFIX=/hbb_shlib \
				-DCMAKE_C_FLAGS="$STATICLIB_CFLAGS" \
				-DCMAKE_CXX_FLAGS="$STATICLIB_CFLAGS" \
				-DCMAKE_LDFLAGS="$LDFLAGS" \
				-DDISABLE_SHARED=1 \
				-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
				.
			run make -j$MAKE_CONCURRENCY libmysql
			run make -C libmysql install
			run make -C include install
			run make -C scripts install
			# https://stackoverflow.com/a/44790834/11598969
			run sed -i 's|libs="$libs -l "|libs="$libs -l mysqlclient -lstdc++"|' /hbb_shlib/bin/mysql_config
		)
		if [[ "$?" != 0 ]]; then false; fi

		echo "Leaving source directory"
		popd >/dev/null
		run rm -rf mysql-connector-c-$MYSQL_LIB_VERSION-src
	fi
fi
### PostgreSQL

if [[ $SKIP_POSTGRESQL != true ]]; then
header "Installing PostgreSQL"
	if [[ ! -e /hbb_shlib/lib/libpq.a ]]; then
		download_and_extract postgresql-$POSTGRESQL_VERSION.tar.bz2 \
			postgresql-$POSTGRESQL_VERSION \
			https://ftp.postgresql.org/pub/source/v$POSTGRESQL_VERSION/postgresql-$POSTGRESQL_VERSION.tar.bz2

		(
			source /hbb_shlib/activate
			export CFLAGS="$STATICLIB_CFLAGS"
			export CXXFLAGS="$STATICLIB_CFLAGS"
			run ./configure --prefix=/hbb_shlib
			# PostgreSQL's build system sometimes fails when building with
			# concurrency, so we don't do it.
			run make -C src/common
			run make -C src/backend
			run make -C src/interfaces/libpq
			run make -C src/interfaces/libpq install-strip
			run make -C src/include
			run make -C src/include install-strip
			run make -C src/bin/pg_config
			run make -C src/bin/pg_config install-strip

			run rm /hbb_shlib/lib/libpq.*
			run mkdir libpq-tmp
			echo "Entering libpq-tmp"
			cd libpq-tmp
			run ar -x ../src/interfaces/libpq/libpq.a
			run ar -x ../src/common/libpgcommon.a
			run ar -x ../src/port/libpgport.a
			run ar -qs /hbb_shlib/lib/libpq.a ./*.o
			run strip --strip-debug /hbb_shlib/lib/libpq.a
		)
		if [[ "$?" != 0 ]]; then false; fi

		echo "Leaving source directory"
		popd >/dev/null
		run rm -rf postgresql-$POSTGRESQL_VERSION
	fi
fi
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
				fi
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
### libssh2
if [[ $SKIP_LIBSSH2 != true ]]; then
header "Installing libssh2"
	if [[ ! -e /hbb_shlib/lib/libssh2.a ]]; then
		download_and_extract libssh2-$LIBSSH2_VERSION.tar.gz \
			libssh2-$LIBSSH2_VERSION \
			https://www.libssh2.org/download/libssh2-$LIBSSH2_VERSION.tar.gz

		(
			source /hbb_shlib/activate
			export CFLAGS="$STATICLIB_CFLAGS"
			export CXXFLAGS="$STATICLIB_CXXFLAGS"
			unset LDFLAGS
			run ./configure --prefix=/hbb_shlib --enable-static --disable-shared \
				--with-openssl --with-libz --disable-examples-build --disable-debug
			run make -j$CONCURRENCY
			run make install-strip -j$CONCURRENCY
		)
		if [[ "$?" != 0 ]]; then false; fi

		echo "Leaving source directory"
		popd >/dev/null
		run rm -rf libssh2-$LIBSSH2_VERSION
	fi
fi
### libyaml
if [[ $SKIP_LIBYAML != true ]]; then
header "Installing libyaml"
	if [[ ! -e /hbb_shlib/lib/libyaml.a ]]; then
		download_and_extract yaml-$LIBYAML_VERSION.tar.gz \
			yaml-$LIBYAML_VERSION \
			https://github.com/yaml/libyaml/releases/download/$LIBYAML_VERSION/yaml-$LIBYAML_VERSION.tar.gz

		(
			source /hbb_shlib/activate
			export CFLAGS="$STATICLIB_CFLAGS"
			export CXXFLAGS="$STATICLIB_CXXFLAGS"
			unset LDFLAGS
			header "libyaml - configure"
			run ./configure --prefix=/hbb_shlib --enable-static --disable-shared
			header "libyaml - make"
			find -name libyaml*
			run make -j$CONCURRENCY
			header "libyaml - post make"
			find -name libyaml*
			run ls
			header "libyaml - install-strip"
			find -name libyaml*
			run make install-strip -j$CONCURRENCY
			header "libyaml - post install-strip"
			find -name libyaml*
			run ls /hbb_shlib/lib/
			header "libyaml - strip --strip-debug"
			find -name libyaml*
			run strip --strip-debug /hbb_shlib/lib/libyaml.a
			header "libyaml - post strip --strip-debug /hbb_shlib/lib/libyaml.a"
			find -name libyaml*
			run ls /hbb_shlib/lib/
		)
		if [[ "$?" != 0 ]]; then false; fi

		echo "Leaving source directory"
		popd >/dev/null
		run rm -rf yaml-$LIBYAML_VERSION

	else
		echo "yaml-$LIBYAML_VERSION Already installed."
	fi
fi
# ### libffi

# header "Installing libffi"
if [[ $SKIP_LIBFFI != true ]]; then
	if [[ ! -e /hbb_shlib/lib/libffi.a ]]; then
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
			run make -j$CONCURRENCY
			run ls
			header "libffi - install-strip"
			run make install-strip -j$CONCURRENCY
			header "libffi - ls /hbb_shlib/lib"
			run ls /hbb_shlib/lib/
			header "libffi - strip --strip-debug"
			# run ar -qs /hbb_shlib/lib/libpq.a ./*.o
			# run strip --strip-debug /hbb_shlib/lib64/libffi.a
			# run strip --strip-debug /hbb_shlib/lib64/libffi.so
			# run strip --strip-debug /hbb_shlib/lib64/libffi.so.8
			# run strip --strip-debug /hbb_shlib/lib64/libffi.so.8.1.0
			header "libffi - ls /hbb_shlib/lib"
			run ls /hbb_shlib/lib/
		)
		if [[ "$?" != 0 ]]; then false; fi

		echo "Leaving source directory"
		popd >/dev/null
		run rm -rf libffi-$LIBFFI_VERSION

	else
		echo "libffi-$LIBFFI_VERSION Already installed."
	fi
fi
run ls /hbb_shlib/lib/

# echo

### Cleanup
if [[ $SKIP_CLEANUP != true ]]; then
	rm -rf /tr_build /tmp/*
fi
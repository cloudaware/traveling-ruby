#!/usr/bin/env bash
set -e
# shellcheck source=linux/image/functions.sh
source /tr_build/functions.sh

MYSQL_LIB_VERSION=6.1.9
MAKE_CONCURRENCY=10
SKIP_MYSQL=${SKIP_MYSQL:-true}

### MySQL
if [[ $SKIP_MYSQL != true ]]; then
	header "Installing MySQL"
	if [[ ! -e /hbb_shlib/lib/libmysqlclient.a ]]; then
		download_and_extract mysql-connector-c-$MYSQL_LIB_VERSION-src.tar.gz \
			mysql-connector-c-$MYSQL_LIB_VERSION-src \
			http://dev.mysql.com/get/Downloads/Connector-C/mysql-connector-c-$MYSQL_LIB_VERSION-src.tar.gz

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
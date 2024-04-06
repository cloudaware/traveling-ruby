#!/usr/bin/env bash
set -e
# shellcheck source=linux/image/functions.sh
source /tr_build/functions.sh


LIBYAML_VERSION=0.2.5
MAKE_CONCURRENCY=10

SKIP_LIBYAML=${SKIP_LIBYAML:-true}


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
			run make -j$MAKE_CONCURRENCY
			header "libyaml - post make"
			find -name libyaml*
			run ls
			header "libyaml - install-strip"
			find -name libyaml*
			run make install-strip -j$MAKE_CONCURRENCY
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
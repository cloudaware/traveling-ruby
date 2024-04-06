#!/usr/bin/env bash
set -e
# shellcheck source=linux/image/functions.sh
source /tr_build/functions.sh


SKIP_CLEANUP=${SKIP_CLEANUP:-true}

run ls /hbb_shlib/lib/
run ls /hbb_shlib/lib64 || echo true
run ls /lib/*
run ls /usr/lib/*

# echo

### Cleanup
if [[ $SKIP_CLEANUP != true ]]; then
	rm -rf /tr_build /tmp/*
	if [[ -f "/etc/debian_version" ]]; then
		echo "Debian"
	elif [[ -f "/etc/centos-release" ]]; then
		yum clean all
	fi
fi
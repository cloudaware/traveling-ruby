#!/usr/bin/env bash
set -e
# shellcheck source=linux/image/functions.sh
source /tr_build/functions.sh
SKIP_INITIALIZE=${SKIP_INITIALIZE:-true}


### Install base software
if [[ $SKIP_INITIALIZE != true ]]; then

	echo "$ARCHITECTURE" >/ARCHITECTURE
	if [[ -f "/etc/debian_version" ]]; then
		run apt-get -y install libreadline-dev libncurses5-dev libncursesw5-dev
	elif [[ -f "/etc/centos-release" ]]; then
		run yum install -y wget sudo readline-devel ncurses-devel s3cmd
		run create_user app "App" 1000
	fi
	run mkdir -p /ccache
fi

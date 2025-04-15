#!/bin/sh

if [ "${TERM}" != "" ] ;then
	# launched attached to a terminal session; do not use LaunchServices:
	exec @KDEAPPDIR@/kdeinit4.app/Contents/MacOS/kdeinit4 "$@"
else
	exec open -W -a @KDEAPPDIR@/kdeinit4.app --args "$@"
fi

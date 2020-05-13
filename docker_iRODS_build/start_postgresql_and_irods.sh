#!/bin/bash
service postgresql start
x=${DB_WAIT_SEC:-15}
while [ $x -ge 0 ] && { ! $SUDO su - postgres -c "psql -c '\l' >/dev/null 2>&1" || x=""; }
do
  [ -z "$x" ] && break
  echo >&2 "$((x--)) secs til database timeout"; sleep 1
done
[ -z "$x" ] || { echo >&2 "Error -- database didn't start" ; exit 1; }

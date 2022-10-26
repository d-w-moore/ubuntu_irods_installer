#!/bin/bash
service postgresql start
x=${DB_WAIT_SEC:-20}
while [ $x -ge 0 ] && { ! $SUDO su - postgres -c "psql -c '\l' >/dev/null 2>&1" || x=""; }
do
  [ -z "$x" ] && break
  echo >&2 "$((x--)) secs til database timeout"; sleep 1
done
[ -z "$x" ] || { echo >&2 "Error -- database didn't start" ; exit 1; }
if ! id -u irods >/dev/null 2>&1 ; then
    if [ -f "${ICAT_DEFERRED_CREATEDB}" ] ; then
        ~/ubuntu_irods_installer/install.sh --w=create-db 0
        rm -f "${ICAT_DEFERRED_CREATEDB}"
    fi
    VERSION_file=$(ls /var/lib/irods/{VERSION,version}.json.dist 2>/dev/null)
    IRODS_VSN=$(jq -r '.irods_version' $VERSION_file) ~/ubuntu_irods_installer/install.sh 5
else
    su - irods -c '~/irodsctl start'
fi

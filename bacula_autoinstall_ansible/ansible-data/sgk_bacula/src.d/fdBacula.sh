#!/bin/bash

. installFunc.sh
. utils.d/CSV.sh

echo "Запуск скрипта для клиента"

NEWFILE="/etc/bacula/bacula-fd.conf"
template=$(echo "$HOSTNAME-fd")

if [[ ! -f "$NEWFILE" ]]; then
	apt update
	apt install bacula-fd -y

	cat $WORKDIR/bacula-fd.conf.sample > "$NEWFILE"
	chmod 644 "$NEWFILE"
	chown root:bacula "$NEWFILE"
fi

if grep "${HOSTNAME}-fd" "$DIRPARAMFILE" | grep Set_DB >/dev/null; then
	addScriptDB
fi
addSectionDirector "$NEWFILE"

editFileFromCSV $NEWFILE $CLIENTPARAMFILE $template

systemctl restart bacula-fd
systemctl status bacula-fd

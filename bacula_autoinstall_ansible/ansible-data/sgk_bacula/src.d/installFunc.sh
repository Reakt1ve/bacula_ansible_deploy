#!/bin/bash

WORKDIR=/usr/doc/ansible/bacula/sgk_bacula
HOSTNAME=$(echo `hostname`)

function addScriptDB(){
	local target_dir=/root/sh
	mkdir -p ${target_dir}

	cp ${WORKDIR}/scripts.d/backup_db.sh.sample ${target_dir}/backup_db.sh
	cp ${WORKDIR}/scripts.d/clear_backup.sh.sample ${target_dir}/clear_backup.sh

	chmod 777 /root/sh/*.sh
}

### $1 изменяемый файл
function addSectionDirector(){
	cat $WORKDIR/sectionDirector.conf.sample >> "$1"
}

function checkUserBacula(){
	if grep bacula /etc/passwd >/dev/null
	then
		echo "true"
	else
		echo "false"
	fi
}

function addUserBacula(){
	if grep bacula /etc/passwd >/dev/null
	then
		return 0
	fi

	adduser --system --group --home /var/lib/bacula tempbaculauser
	sed -i 's/tempbaculauser/bacula/g' /etc/passwd* /etc/group* /etc/shadow*
	usermod -c "Bacula" bacula
	usermod -G tape bacula
	chown bacula:bacula -R /var/lib/bacula

	mkdir /var/log/bacula
	chown bacula:bacula -R /var/log/bacula
	mkdir /run/bacula
	chown bacula:bacula /run/bacula
}

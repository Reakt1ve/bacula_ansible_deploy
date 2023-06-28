#!/bin/bash

. installFunc.sh
. utils.d/CSV.sh

echo "Запуск скрипта для хранилища"

apt install bacula-sd bacula-common-pgsql -y
if ! grep "/backups/bacula" /etc/fstab >/dev/null
then
	fdisk /dev/sdd << EEOF
o
n
p
1


w
EEOF

	part="/dev/sdd1"
	mkfs.ext4 $part

	mkdir -p /backups/bacula
	mount $part /backups/bacula
	chown -R bacula:bacula /backups

	echo "${part} /backups/bacula ext4 defaults 0 2" >> /etc/fstab
fi

rm /backups/bacula/* 2>/dev/null
chown -R bacula:bacula /backups

declare -A tree_data=( \
			["workdir","bacula-sd"]="/etc/bacula/" \
			["algorithm","bacula-sd"]="content" \
			["output","bacula-sd"]="bacula-sd.conf" \
			["csv_row","bacula-sd"]="${HOSTNAME}-sd" \
			["storage_path","bacula-sd"]="$STORAGEPARAMFILE" \
			["insert_content_from","bacula-sd"]="$WORKDIR/bacula-sd.conf.sample" \
)

addFileTree tree_data "csv"

echo "Конфигурация bacula-sd успешно завершена"

systemctl restart bacula-sd
systemctl status bacula-sd

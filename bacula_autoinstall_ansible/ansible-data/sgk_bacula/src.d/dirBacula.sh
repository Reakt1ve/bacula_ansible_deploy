#!/bin/bash

. installFunc.sh
. utils.d/file.sh
. utils.d/file_path.sh
. utils.d/struct.sh
. utils.d/CSV.sh
. utils.d/string.sh

mkdir -p /var/log/sgk_bacula
>/var/log/sgk_bacula/debug.log

function create_bacula_db(){
	if ! echo "\l" | sudo -u postgres psql 2>&1 | grep bacula >/dev/null; then
		usermod -a -G shadow postgres
		setfacl -d -m u:postgres:r /etc/parsec/macdb
		setfacl -R -m u:postgres:r /etc/parsec/macdb
		setfacl -m u:postgres:rx /etc/parsec/macdb
		setfacl -d -m u:postgres:r /etc/parsec/capdb
		setfacl -R -m u:postgres:r /etc/parsec/capdb
		setfacl -m u:postgres:rx /etc/parsec/capdb

		systemctl stop bacula-director
		echo "DROP DATABASE bacula" | su postgres -c psql
		echo "CREATE USER bacula WITH PASSWORD '123qwerASDuser'" | su postgres -c psql
		echo "CREATE DATABASE bacula WITH OWNER = 'bacula' ENCODING = 'SQL_ASCII' LC_COLLATE = 'C' LC_CTYPE = 'C' TEMPLATE = 'template0'" | su postgres -c psql
		pdpl-user bacula -z
		sudo -u bacula bash $WORKDIR/postgres.d/make_postgresql_tables_bacula.sh
	fi
}

echo "Запуск скрипта для директора"

### Добавление IP плана в /usr/doc/bacula
target_csv_filename=$(basename $1)
if echo "$target_csv_filename" | grep "ЦУ-1" 1>/dev/null; then
	cp -a $WORKDIR/share.d/IP_план_ПЗ_одна_подсеть_финал_v2.1.xlsx /usr/doc/bacula/
fi

### Настройка установщика apt
apt update
echo "bacula-director-pgsql bacula-director-pgsql/dbconfig-install boolean false" | debconf-set-selections
apt install bacula-director-pgsql bacula-director bacula-console* -y

### Установка и настрока базы данных bacula
create_bacula_db
sed -i "/listen/s/localhost/\*/" /etc/postgresql/9.6/main/postgresql.conf >/dev/null
service postgresql restart

rm -r /etc/bacula/*.d 2>/dev/null
mkdir -p /etc/bacula/{job.d,client.d,fileset.d,schedule.d,pool.d,storage.d,message.d,catalog.d} \
	 && chown root:bacula /etc/bacula/{job.d,client.d,fileset.d,schedule.d,pool.d,storage.d,message.d,catalog.d} \
	 && chmod 755 /etc/bacula/{job.d,client.d,fileset.d,schedule.d,pool.d,storage.d,message.d,catalog.d}

### Преднастройка fileset'ов
fileset_clone_col_idx=$(getIdxCSVCell $DIRPARAMFILE "Full_Set")
template=$(echo "${HOSTNAME}-dir,")
#echo $col_for_file
fileset_clone_files=$(getCSVCellVal $DIRPARAMFILE $fileset_clone_col_idx $template "greedy")
#echo $fileset_clone_files
fileset_clone_files=$(replaceText "$fileset_clone_files" "$" ".conf.sample")
#echo $fileset_clone_files

cp -a $WORKDIR/fileset.d/Full_Set.conf.sample /etc/bacula/fileset.d/Full_Set.conf
chmod 644 /etc/bacula/fileset.d/Full_Set.conf
chown root:bacula /etc/bacula/fileset.d/Full_Set.conf

### Настрйока файлов конфигурации Bacula director
declare -A tree_data=( \
					["workdir","pool"]="/etc/bacula/" \
					["algorithm","pool"]="file" \
					["output","pool"]="pool.d/" \
					["csv_column","pool"]="File" \
					["csv_row","pool"]="${HOSTNAME}-dir" \
					["storage_path","pool"]="$DIRPARAMFILE" \
					["insert_content_from","pool"]="${WORKDIR}/pool.d/dir01.conf.sample" \
					\
					["workdir","storage"]="/etc/bacula/" \
					["algorithm","storage"]="file" \
					["output","storage"]="storage.d/" \
					["csv_column","storage"]="stor-sd" \
					["csv_row","storage"]="${HOSTNAME}-dir" \
					["storage_path","storage"]="$STORAGEPARAMFILE" \
					["insert_content_from","storage"]="${WORKDIR}/storage.d/dirSd.conf.sample" \
					\
					["workdir","bconsole"]="/etc/bacula/" \
					["algorithm","bconsole"]="content" \
					["output","bconsole"]="bconsole.conf" \
					["csv_row","bconsole"]="${HOSTNAME}-dir" \
					["storage_path","bconsole"]="$DIRPARAMFILE" \
					["insert_content_from","bconsole"]="${WORKDIR}/bconsole.conf.sample" \
					\
					["workdir","schedule"]="/etc/bacula/" \
					["algorithm","schedule"]="clone" \
					["output","schedule"]="schedule.d/" \
					["insert_content_from","schedule"]="${WORKDIR}/schedule.d" \
					\
					["workdir","fileset"]="/etc/bacula/" \
					["algorithm","fileset"]="clone" \
					["clone_exact","fileset"]="$fileset_clone_files" \
					["output","fileset"]="fileset.d/" \
					["insert_content_from","fileset"]="${WORKDIR}/fileset.d" \
					\
					["workdir","message"]="/etc/bacula/" \
					["algorithm","message"]="clone" \
					["output","message"]="message.d/" \
					["insert_content_from","message"]="${WORKDIR}/message.d/mesDef.conf.sample" \
					\
					["workdir","client"]="/etc/bacula/" \
					["algorithm","client"]="file" \
					["output","client"]="client.d/" \
					["csv_column","client"]="dir-fd" \
					["csv_row","client"]="${HOSTNAME}-dir" \
					["storage_path","client"]="$CLIENTPARAMFILE" \
					["insert_content_from","client"]="${WORKDIR}/client.d/dir-fd.conf.sample" \
					\
					["workdir","job"]="/etc/bacula/" \
					["algorithm","job"]="file" \
					["output","job"]="job.d/" \
					["csv_column","job"]="BackupBD" \
					["csv_row","job"]="${HOSTNAME}-dir" \
					["storage_path","job"]="$DIRPARAMFILE" \
					["insert_content_from","job"]="${WORKDIR}/job.d/dirTest.conf.sample" \
					\
					["workdir","bacula-dir"]="/etc/bacula/" \
					["algorithm","bacula-dir"]="content" \
					["output","bacula-dir"]="bacula-dir.conf" \
					["csv_row","bacula-dir"]="${HOSTNAME}-dir" \
					["storage_path","bacula-dir"]="$DIRPARAMFILE" \
					["insert_content_from","bacula-dir"]="$WORKDIR/bacula-dir.conf.sample" \
					\
					["workdir","bat"]="/etc/bacula/" \
					["algorithm","bat"]="content" \
					["output","bat"]="bat.conf" \
					["csv_row","bat"]="${HOSTNAME}-dir" \
					["storage_path","bat"]="$DIRPARAMFILE" \
					["insert_content_from","bat"]="$WORKDIR/bat.conf.sample" \
					\
					["workdir","catalog"]="/etc/bacula/" \
					["algorithm","catalog"]="content" \
					["output","catalog"]="catalog.d/" \
					["csv_row","catalog"]="${HOSTNAME}-dir" \
					["storage_path","catalog"]="$DIRPARAMFILE" \
					["insert_content_from","catalog"]="$WORKDIR/catalog.d/catalog.conf.sample" \
			  )

addFileTree tree_data "csv"

echo "Конфигурация Bacula director успешно завершена"

systemctl restart bacula-director
systemctl status bacula-director

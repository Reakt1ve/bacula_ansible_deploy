#!/bin/bash

. installFunc.sh
. utils.d/CSV.sh

dir_col=1
sd_col=2
fd_col=2

addUserBacula

let failed=0
for param in dir sd fd; do
	col_param=$(echo ${param}_col) #dir_col
	col_param_1=$(eval echo \$${col_param}) #$dir_col
	list_param_files=$(ls ${WORKDIR}/csv.d/*.${param}.csv)
	pattern=$(echo "${HOSTNAME}-${param},")
	list_target_csv=$(findCSVByContent "$list_param_files" "$pattern")

	OLD_IFS=$IFS
	IFS=$';'
	for target_csv in $list_target_csv; do
		if [[ ! -z $target_csv ]]; then
			hostname_dir=$(getCSVCellVal $target_csv $col_param_1 $pattern)
			if [[ ! -z $hostname_dir ]]; then
				#echo "$target_csv"
				BASENAME=$(echo $target_csv | rev | cut -d '/' -f1 | rev | cut -d '.' -f1)
				export DIRPARAMFILE="${WORKDIR}/csv.d/${BASENAME}.dir.csv"
				export CLIENTPARAMFILE="${WORKDIR}/csv.d/${BASENAME}.fd.csv"
				export STORAGEPARAMFILE="${WORKDIR}/csv.d/${BASENAME}.sd.csv"

				./${param}Bacula.sh $target_csv 2>&1
				error_code=$?
				if [ $error_code -ne 0 ]; then
					failed=1
				fi
			fi
		fi

	done
	IFS=$OLD_IFS
done

if [ $failed -ne 0 ]; then
	exit -1
fi

exit 0

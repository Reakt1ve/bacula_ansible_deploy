#!/bin/bash

function getListPathsElement(){
	local user_elem_name=$(echo $2)
	local list_available_paths_elem="file_path file_name file_extention"

	for elem in $list_available_paths_elem; do
		#echo $elem
		if echo "$user_elem_name" | grep "$elem" >/dev/null; then
			local list_context_filesname=$(echo "$1")
			#echo $list_context_filesname
			declare -A path_hash
			declare -a list_primary_val_csv_arr
			local let primary_val_idx=0
			OLD_IFS=$IFS
			IFS=$';'
			for context_filename in $list_context_filesname; do
				#echo $context_filename "sdsdsdsdsd"
				#echo "sddfdf"
				parseFilePath $context_filename path_hash
				#echo ${path_hash[file_name]} "23232323"
				list_primary_val_csv_arr[$primary_val_idx]=$(echo ${path_hash["file_name"]})
				((primary_val_idx++))
			done
			IFS=$OLD_IFS

			#echo ${list_primary_val_csv_arr[0]}
			printf "%s;" "${list_primary_val_csv_arr[@]}"
			return
		fi
	done

	echo "[Error:getListPathsElement()] - Неверно передан аргумент функции" >> /var/log/sgk_bacula/debug.log
	echo "[Error] - Аварийный выход из программы" >> /var/log/sgk_bacula/debug.log
	exit -1
}

function parseFilePath(){
	local list_paths=$(echo "$1")
	local -n path_hash_table=$2
	#echo "$list_paths"

	if echo "$1" | grep -E "/$" >/dev/null; then
		local temp=$(echo "$1" | sed 's/.$//')
	else
		local temp=$(echo "$1")
	fi

	path_hash_table["file_path"]=$(echo "$temp" | rev | awk -F "/" 'BEGIN{OFS="/"}{$1="";print $0}' | rev)
	path_hash_table["file_name"]=$(echo "$temp" | rev | cut -d '/' -f1 | cut -d"." -f1 --complement | rev)
	path_hash_table["file_extention"]=$(echo "$list_paths" | rev | cut -d'.' -f1 | rev)

	#echo ${path_hash_table["file_path"]}
}

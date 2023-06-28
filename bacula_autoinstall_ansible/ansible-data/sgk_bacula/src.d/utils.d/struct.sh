#!/bin/bash

function getHashSetElement(){
	local -n hash_elem=$3
	local search_hashSet_obj=$(echo $2)
	local -n hashSet=$1

	#echo "obj: " $search_hashSet_obj
	#echo "feature: " ${hash_elem["clone_exact"]}
	#echo "hash_set:" ${hashSet["clone_exact","message"]}

	declare -a _passed_objects
	local let _passed_objects_iter=0
	for data_row in ${!hashSet[@]}; do
		local object=$(echo "$data_row" | cut -d',' -f2)
		if echo "$object" | grep "$search_hashSet_obj" >/dev/null; then
			local feature=$(echo "$data_row" | cut -d',' -f1)
			#echo "$feature" "$object" ${hashSet["$feature","$object"]}
			hash_elem["$feature"]=${hashSet["$feature","$object"]}
		fi
	done

	#for key in ${!hash_elem[@]}; do
	#	echo "key;" $key
	#	echo "val: " ${hash_elem["$key"]}
	#done
}

### $1 - 1 список
### $2 - 2 список
### $3 - итоговый hash
### $4 - политика связывания (появится по необходимости. По умолчанию связывание 1 к 1)
function bindLists(){
	local f_list=$(echo "$1")
	local s_list=$(echo "$2")

	#echo "f_list: " $f_list
	#echo "s_list: " $s_list
	local -n _hash=$3

	IFS=';' read -r -a list_new_files_arr <<< "$s_list"
	IFS=';' read -r -a list_files_names_arr <<< "$f_list"

	#echo ${list_new_files_arr[@]}
	#echo ${list_files_names_arr[@]}

	for(( arr_idx=0;arr_idx<${#list_new_files_arr[@]};arr_idx++ )); do
		_hash["${list_new_files_arr[$arr_idx]}"]="${list_files_names_arr[$arr_idx]}"
		#echo ${list_new_files_arr[$arr_idx]} ${_hash[${list_new_files_arr[$arr_idx]}]}
	done
}

### $1 - массив пройденных элементов
function clearSet(){
	local -n passed_buff=$1
	local -n _isCleared=$2

	local let before_size=${#passed_buff[@]}
	passed_buff=($(echo ${passed_buff[@]} | tr ' ' '\n' | sort -u | tr '\n' ' '))
	local let after_size=${#passed_buff[@]}
	local let diff_size=$before_size-$after_size

	if [[ $diff_size -ne 0 ]]; then
		_isCleared="true"
	else
		_isCleared="false"
	fi
}

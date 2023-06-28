#!/bin/bash

function cloneFiles(){
	local _clone_from=$(echo $1)
	local _clone_to=$(echo $2)

	#echo "from: " "$_clone_from"
	#echo "to: " "$_clone_to"

	OLD_IFS=$IFS
	IFS=$';'
	for file in $_clone_from; do
		#echo $file
		cp -a $file ${_clone_to}
	done
	IFS=$OLD_IFS

	find $_clone_to -type f -printf '%p;'
}

### $1 - модифицируемый файл
### $2 - Hash с параметрами
### Note: ext - extention (расширение файла)
function modifyFile(){
	local file=$(echo "$1")
	local -n _m_options=$2

	local _modified_file=$(echo "$file")
	#echo $file

	if [[ ! -z ${_m_options[ext]} ]]; then
		_modified_file=$(replaceText "$file" ${_m_options[ext_regex]} ${_m_options[ext]})
		#echo $_modified_file
		mv "$file" $_modified_file 2>/dev/null
	fi

	if [[ ! -z ${_m_options[owner]} ]]; then
		chown ${_m_options[owner]} $_modified_file
	fi

	if [[ ! -z ${_m_options[access]} ]]; then
		chmod ${_m_options[access]} $_modified_file
	fi
}

function addParamToFile(){
	local -n hash_params=$1
	local modify_file=$(echo $2)

	for key in ${!hash_params[@]}; do
		sed -i -e "/}/i \        ${key} = ${hash_params[$key]}" $(echo "$modify_file")
	done
}

function massInsertToFilesFromTemplate(){
	local list_files=$(echo $1)
	local template_file=$(echo "$2")
	#echo "list: " $list_files
	#echo "template: " $template_file

	OLD_IFS=$IFS
	IFS=$';'
	for file in $list_files; do
		cat "$template_file" > "$file"
	done
	IFS=$OLD_IFS
}

# $1 файл/файлы
function generateFiles(){
	OLD_IFS=$IFS
	IFS=';'
	for str in $1; do
		touch $str
	done
	IFS=$OLD_IFS
}

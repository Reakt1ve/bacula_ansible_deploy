#!/bin/bash

### $1 заменяемый текст
### $2 подстрока заменитель
### $3 подстрока заменяемый
### $4 sed разделитель
function replaceText(){
	declare -a replace_text_arr
	let replace_text_arr_idx=0

	if [[ -z $4 ]]; then
		sed_delim="/"
	else
		sed_delim="$4"
	fi

	OLD_IFS=$IFS
	IFS=$';'
	for text in $1; do
		replace_text_arr[${replace_text_arr_idx}]=$(echo "$text" | sed s${sed_delim}$2${sed_delim}$3${sed_delim}g)
		((replace_text_arr_idx++))
	done
	IFS=$OLD_IFS

	printf '%s;' "${replace_text_arr[@]}"
}

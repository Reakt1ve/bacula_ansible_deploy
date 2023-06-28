#!/bin/bash

. utils.d/string.sh
. utils.d/file.sh
. utils.d/file_path.sh
. utils.d/struct.sh

function addFileTree(){
	local -n module_data=$1
	local type_storage=$(echo $2)

	### Условие для добавления новых внешних хранилищ
	if echo "$type_storage" | grep -i "csv" > /dev/null; then
		addCSVFileTree module_data
	else
		echo "[Error:addContentInDirFromCSV():CSV] - Неверно передан аргумент функции" >> /var/log/sgk_bacula/debug.log
		echo "[Error] - Аварийный выход из программы" >> /var/log/sgk_bacula/debug.log
		exit -1
	fi
}

### $1 - Идентичен fileStrategy $1 (обший интерфейс)
function CSVfileInteractCloneStrategy(){
	local -n data=$1
	#echo "data: " ${data[@]}

	OLD_IFS=$IFS
	IFS=$";"
	local find_pattern="-type f"
	#echo $find_pattern
	let clone_exact_iter=0
	for exact_file in ${data[clone_exact]}; do
		if [[ $clone_exact_iter -eq 0 ]]; then
			find_pattern=$(echo -e $find_pattern " -name $exact_file")
		fi

		find_pattern=$(echo -e $find_pattern " -o -name $exact_file")
		((clone_exact_iter++))
	done
	IFS=$OLD_IFS

	find_predicate=$(echo "${data[insert_content_from]}" "$find_pattern")
	#echo $find_predicate
	local clone_from=$(find $find_predicate | tr '\n' ';')
	#echo "clone_from: " $clone_from
	local cloned_paths=$(cloneFiles $clone_from ${data[output]})
	#echo "cloned_paths: " $cloned_paths
	declare -A _file_options=( \
			["ext"]=".conf" \
			["ext_regex"]=".conf.sample" \
			["owner"]="root:bacula" \
			["access"]="644" \
	)

	OLD_IFS=$IFS
	IFS=$';'
	for path in $cloned_paths; do
		#echo $path
		modifyFile $path _file_options
	done
	IFS=$OLD_IFS
}

### $1 - Идентичен fileStrategy $1 (общий интерфейс)
### Обобщению не подлежит из-за технических ограничений базы (работа с 1 файлом)
function CSVfileInteractContentStrategy(){
	local -n _data=$1

	CSVfileInteractCloneStrategy _data
	cloned_file=$(find ${_data[output]} -type f)
	#echo $cloned_file

	local -A hash_csv_row_view=(["$cloned_file"]=$(echo ${_data[csv_row]}))
	#echo ${hash_csv_row_view[@]}
	fillTemplatesFileFromCSV hash_csv_row_view "${_data[storage_path]}"
}

### $1 - Hash типа <параметр,значение>
function CSVfileInteractStrategy(){
	local -n data=$1
	#echo "${data[insert_content_from]}"

	local created_files
	createFilesByCSVDataset "${data[csv_column]}" "${data[csv_row]}" "${data[storage_path]}" "${data[output]}" created_files
	#echo $created_files
	massInsertToFilesFromTemplate "$created_files" "${data[insert_content_from]}"
	local list_files_names=$(getListPathsElement "$created_files" "file_name")
	#echo $list_files_names
	local -A hash_csv_row_view
	bindLists "$list_files_names" "$created_files" hash_csv_row_view

	if echo ${data[output]} | grep "job.d" >/dev/null; then
		OLD_IFS=$IFS
		IFS=$';'
		for file in $created_files; do
			addClientRunJobsCSVToJobFile data $file ### костыль, который тянется от функции CSVfileInteractContentStrategy
		done
		IFS=$OLD_IFS
	fi

	fillTemplatesFileFromCSV hash_csv_row_view "${data[storage_path]}"
}

function CSVFileInteractStrategyContext(){
	local -n _strategy_hash=$1
	local strategy_type=$(echo ${_strategy_hash[algorithm]})

	cd "${_strategy_hash[workdir]}"

	#echo "hash: " ${_strategy_hash[@]}
	#echo "type: " $strategy_type

	case $strategy_type in
		clone)
			CSVfileInteractCloneStrategy _strategy_hash
		;;
		content)
			CSVfileInteractContentStrategy _strategy_hash
		;;
		file)
			CSVfileInteractStrategy _strategy_hash
		;;
		*)
			echo "[Error:addCSVFileTree():builder_type] - Неверно передан аргумент функции" >> /var/log/sgk_bacula/debug.log
			echo "[Error:addCSVFileTree()] - Аварийный выход" >> /var/log/sgk_bacula/debug.log
			exit -1
		;;
	esac
}

function addCSVFileTree(){
	local -n data=$1
	#echo ${data["output","pool"]} ${data["csv_column","pool"]} ${data["csv_row","pool"]} ${data["storage_path","pool"]}

	declare -a passed_objects
	local let passed_objects_iter=0
	for keys in ${!data[@]}; do
		declare -A strategy_hash
		### Блок исключения повторений
		local object=$(echo "$keys" | cut -d',' -f2)
		#echo "object: " $object
		passed_objects[$passed_objects_iter]=$(echo $object)
		((passed_objects_iter++))
		clearSet passed_objects isCleared
		#echo ${passed_objects[@]}
		if echo "$isCleared" | grep true >/dev/null; then
			((passed_objects_iter--))
			continue
		fi

		getHashSetElement data $object strategy_hash
		#echo "searching obj: " $object
		#echo "hash: " ${strategy_hash[@]}
		CSVFileInteractStrategyContext strategy_hash
		unset strategy_hash
	done
}

function createFilesByCSVDataset(){
	local csv_col=$(echo $1)
	local csv_row=$(echo $2)
	local csv_file_path=$(echo $3)
	local output_path=$(echo $4)
	local -n _created_files=$5

	#echo $csv_col $csv_row $csv_file_path $output_path

	local num_of_column=$(getIdxCSVCell $csv_file_path "$csv_col")
	#echo $num_of_column
	local list_files_body=$(getCSVCellVal $csv_file_path $num_of_column $csv_row "greedy")
	#echo $list_files_body
	_created_files=$(replaceText "$list_files_body" "$" ".conf")
	_created_files=$(replaceText "$_created_files" "^" "$output_path" "!")
	#echo $_created_files
	generateFiles "$_created_files"

	#echo "${val_of_col_arr[@]}"
	#echo "${job_filesname_arr[@]}"

	echo "$_created_files" | tr " " ";" > /dev/null
}

function addClientRunJobsCSVToJobFile(){
	local -n _data=$1
	local file=$(echo $2)

	local csv_file=${_data[storage_path]}
	local -A path
	parseFilePath $file path
	local support_column=$(echo ${path[file_name]})

	#echo "file: " $file "csv_file: " $csv_file "support_column: " $support_column

	local jb_num=$(getIdxCSVCell $csv_file "Job_before")
	local ja_num=$(getIdxCSVCell $csv_file "Job_after")
	#echo "jb_num: " $jb_num "ja_num: " $ja_num
	local jb_val=$(getCSVCellVal $csv_file $jb_num $support_column)
	local ja_val=$(getCSVCellVal $csv_file $ja_num $support_column)
	#echo "jb_val: " $jb_val "ja_val: " $ja_val

	if [[ ! -z $jb_val && ! -z $ja_val ]]; then
		local ja_val="\"${ja_val}\""
		local jb_val="\"${jb_val}\""
		declare -A conf_params=( \
				["ClientRunBeforeJob"]=$jb_val \
				["ClientRunAfterJob"]=$ja_val \
		)

		addParamToFile conf_params $file
		return
	fi

	if [[ ! -z $jb_val ]]; then
		local jb_val="\"${jb_val}\""
		declare -A conf_params=( \
				["ClientRunBeforeJob"]=$jb_val \
		)
		addParamToFile conf_params $file
		return
	fi

	if [[ ! -z $ja_val ]]; then
		local ja_val="\"${ja_val}\""
		declare -A conf_params=( \
				["ClientRunAfterJob"]=$ja_val \
		)
		addParamToFile conf_params $file
	fi
}

function fillTemplatesFileFromCSV(){
	local -n hash_view=$1
	local csv_file=$(echo "$2")

	#echo ${hash_view[@]} $csv_file

	for file in ${!hash_view[@]}; do
		editFileFromCSV $file $csv_file ${hash_view[$file]}

		chmod 644 $file
		chown root:bacula $file
	done
}

### $1 файл с параметрами для обработки
### $2 название колонки
### $3 название строки
### $4 изменяемый файл
function replaceFromCSVToFile(){
	#echo "$1 12222 $2 12222 $3 12222 $4"
	finded_col=$(getIdxCSVCell "$1" "$2")
	#echo "$finded_col 23232323"
	cell_val=$(getCSVCellVal $1 $finded_col $3)
	#echo "$cell_val"

	sed -i s!COLUMN#$2#!${cell_val}!g $4
}

### $1 CSV файл
### $2 Содержимое ячейки
function getIdxCSVCell(){
	#echo "$1 55555 $2"
	col_list=$(grep -m 1 "$2" "$1")
	#echo "$1 55555 $2 111 $col_list"
	let counter=0
	IFS=$','
	for col in $col_list; do
		((counter++))
		if echo "${col}123" | grep -e "${2}123" >/dev/null; then
			echo "$counter"
			break
		fi
	done
}

### $1 Список csv файлов
### $2 Искомое вхождение
function findCSVByContent(){
	declare -a list_csv_arr
	let list_csv_arr_idx=0

	for csv_file in $1; do
		if grep $2 "$csv_file" >/dev/null; then
			list_csv_arr[$list_csv_arr_idx]="$csv_file"
			((list_csv_arr_idx++))
		fi
	done

	printf '%s;' "${list_csv_arr[@]}"
}

### $1 В каком CSV файле извлекаем
### $2 По какому столбцу искать
### $3 По какой строке искать
### $4 Режим жадного алгоритма (greedy)
function getCSVCellVal(){
	#echo "$1 5555 $2 5555 $3 5555 $4"
	if [[ "$4" == "greedy" ]]; then
		row_list=$(grep "$3" "$1" | tr '\n' '~')

		declare -a cell_val_arr
		let cell_val_arr_idx=0

		IFS=$'~'
		#echo "$1 5555 $2 5555 $3 5555 $4"
		for row in $row_list; do
			cell_val=$(echo $row | cut -d ',' -f"$2")
			cell_val_arr[${cell_val_arr_idx}]="$cell_val"
			((cell_val_arr_idx++))
		done

		printf '%s;' "${cell_val_arr[@]}"
	else
		#echo "$1 77777 $2 7777 $3"
		row=$(grep -m 1 "$3" "$1")
		#echo "$row"
		#echo "$2 col"
			cell_val=$(echo $row | cut -d ',' -f"$2")
		echo $cell_val
	fi
}

### $1 изменяемый файл
### $2 файл с параметрами для обработки
### $3 строка в csv
function editFileFromCSV(){
	### Извлечение строк с паттерном COLUMN#
	list_file_param_str=$(cat $1 | grep COLUMN# | tr '\n' ';')
	#echo $list_file_param_str

	### Поиск числа вхождений COLUMN# в строке
	OLD_IFS=$IFS
	IFS=$';'
	declare -a list_file_param_arr
	let list_file_param_idx=0
	for param_str in $list_file_param_str; do
		count_column_str=$(echo "$param_str" | grep -o COLUMN# | wc -l)
		#echo $count_column_str

		### Извлечение данных из COLUMN#
		let start_num_column=2
		for (( i=0;i<${count_column_str};i++ )); do
			for (( j=0;j<${count_column_str};j++ )); do
				list_file_param_arr[$list_file_param_idx]=$(echo $param_str | grep COLUMN# | cut -d '#' -f${start_num_column})
				let start_num_column+=2
				(( list_file_param_idx++ ))
			done
		done
	done
	IFS=$OLD_IFS
	list_file_param=$(printf '%s\n' "${list_file_param_arr[@]}")

	#echo "NEW $list_file_param NEW"

	#echo "$1 444 $2 444 $3 param $list_file_param"
	#exit 1

	#list_file_param=$(cat $1 | grep COLUMN# | cut -d '#' -f2)
	#echo "$list_file_param OLD"
	OLD_IFS=$IFS
	IFS=$'\n'
	for file_param in $list_file_param; do
		#echo "111 $file_param"
		replaceFromCSVToFile $2 "$file_param" $3 $1
	done
	IFS=$OLD_IFS
}

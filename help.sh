# Help section
show_help() {

	# colors
	local c_red=$(printf '\033[1;31m')
	local c_green=$(printf '\033[1;32m')
	local c_reset=$(printf '\033[0m')

	if [[ -n "$1" ]]; then
		echo -e "\nUnknown option: '${c_red}$1${c_reset}'\n" >&2
	fi

	cat <<-USAGE
	Available options:

	  ${c_green}--mysql-clean${c_reset}         - dump all MySQL databases ${c_red}wthout${c_reset} encryption
	  ${c_green}--mysql-encrypt${c_reset}       - dump all MySQL databases and ${c_red}encrypt${c_reset} them
	  ${c_green}--rsync-master${c_reset}        - rsync databases to the ${c_red}main${c_reset} backup server
	  ${c_green}--rsync-secondary${c_reset}     - rsync databases to the ${c_red}secondary${c_reset} backup server
	  ${c_green}--localbkp-encrypt${c_reset}    - encrypt any custom files in the ${c_red}localbkp${c_reset} directory
	  ${c_green}--restore-decrypt${c_reset}     - decrypt all files in ${c_red}restore${c_reset} directory
	  ${c_green}--files${c_reset}               - backup files/directories from each line in ${c_red}files.conf${c_reset} without encryption
	  ${c_green}--clear-logs${c_reset}          - clear ${c_red}all${c_reset} logs and monitoring checks

USAGE
	exit 1
}

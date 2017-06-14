# colors
c_red="\033[1;31m"
c_green="\033[1;32m"
c_reset="\033[0m"

# Help section
show_help() {

	if [[ -n "$1" ]]; then
		echo -e "Unknown option: '${c_red}$1${c_reset}'\n" >&2
	fi

	echo "Available options:"
	echo
	echo -e "  ${c_green}--mysql-clean${c_reset}         - dump all MySQL databases ${c_red}wthout${c_reset} encryption"
	echo -e "  ${c_green}--mysql-encrypt${c_reset}       - dump all MySQL databases and ${c_red}encrypt${c_reset} them"
	echo -e "  ${c_green}--rsync-master${c_reset}        - rsync databases to the ${c_red}main${c_reset} backup server"
	echo -e "  ${c_green}--rsync-secondary${c_reset}     - rsync databases to the ${c_red}secondary${c_reset} backup server"
	echo -e "  ${c_green}--localbkp-clear${c_reset}      - clear ${c_red}localbkp${c_reset} directory"
	echo -e "  ${c_green}--lokalbkp-check${c_reset}      - check ${c_red}localbkp${c_reset} directory and print if there are any files"
	echo -e "  ${c_green}--localbkp-encrypt${c_reset}    - encrypt any custom files in the ${c_red}localbkp${c_reset} directory"
	echo -e "  ${c_green}--restore-decrypt${c_reset}     - decrypt all files in ${c_red}restore${c_reset} directory"
	echo -e "  ${c_green}--restore-clear${c_reset}       - delete all files from the ${c_red}restore${c_reset} directory"
	echo -e "  ${c_green}--files${c_reset}               - backup files/directories from each line in ${c_red}files.conf${c_reset} without encryption"
	echo -e "  ${c_green}--clear-logs${c_reset}          - clear ${c_red}all${c_reset} logs and monitoring checks"
	echo
	exit 1
}

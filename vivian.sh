#!/bin/bash

# int global
vivian_root=$(readlink -f `dirname $0`)

vivian_version="1.0"
vivian_readme="${vivian_root}/readme"

source $vivian_root/.env

# some globals
this_server=`hostname`
current_date=`date +%Y%m%d-%H%M`

# vivian file backup
vivian_files_conf="${vivian_root}/files.conf"

# global paths
vivian_localbkp="${vivian_root}/localbkp" # storage path
vivian_localbkp_files="${vivian_localbkp}/files" # files/dirs
vivian_restore="${vivian_root}/restore" # restore

source $vivian_root/help.sh
source $vivian_root/mysql.sh
source $vivian_root/encryption.sh
source $vivian_root/rsync.sh
source $vivian_root/cleaner.sh
source $vivian_root/logging.sh

function localbkp_encrypt(){

	# if we have some files in localbkp this function will
	# generate localbkp.tar.gz and will encrypt this file

	# when the file is created, let's create localbkp.tar.gz
	# and move it to localbkp/

	cd $vivian_root

	tar -zcvf $current_date-$this_server-localbkp.tar.gz $vivian_localbkp

	mv $current_date-$this_server-localbkp.tar.gz $vivian_localbkp

	# let's encrypt this archive

	cd $vivian_localbkp

	encrypt_file $current_date-$this_server-localbkp.tar.gz

	log "Custom archive of localbkp was created and secured"

	# delete the archive
	rm -f $current_date-$this_server-localbkp.tar.gz

	send_mail "$this_server: custom localbkp was created and secured" "Log into server and check this backup. If folder isn't empty, the regular backup will fail."

}

function backup_files(){

	# if we have a line in files.conf
	# we will archive it in .tar.gz

	if [ -s "$vivian_files_conf" ];

	then


	mkdir -p $vivian_localbkp_files

	#$files_for_backup=$(cat $vivian_files_conf);

		for files in `cat $vivian_files_conf`
		do
			tar -zcvf ${vivian_localbkp_files}/${current_date}-files.tar.gz $files >> /dev/null
		done


	else

	log "There are no files for backup. Skip."

	fi
}

for arg in "$@"; do
case "$arg" in
	--mysql-clean|mysql-clean)
		mysql_clean $vivian_localbkp
	;;
	--mysql-encrypt|mysql-encrypt)
		mysql_encrypt $vivian_localbkp
	;;
	--rsync|rsync)
		rsync_to_storages
	;;
	--localbkp-clear|localbkp-clear)
		localbkp_clear
	;;
	--localbkp-check|localbkp-check)
		localbkp_check
	;;
	--localbkp-encrypt|localbkp-encrypt)
		localbkp_encrypt
	;;
	--restore-decrypt|restore-decrypt)
		restore_decrypt $vivian_restore
	;;
	--restore-clear|restore-clear)
		restore_clear
	;;
	--files|files)
		backup_files
	;;
	--clear-logs|clear-logs)
		vivian_clear_logs
	;;
	*)
		show_help $arg
esac
done

if [[ -z "$1" ]]; then
	show_help
fi

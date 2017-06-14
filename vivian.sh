#!/bin/bash

# int global
vivian_root=$(readlink -f `dirname $0`)

vivian_version="1.0"
vivian_readme="${vivian_root}/readme"

# email
monitoring_email="monitoring@example.com"

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

# log files
vivian_logs="${vivian_root}/logs"
vivian_logs_general="${vivian_logs}/general.log"
vivian_logs_mon="${vivian_logs}/last_backup"
vivian_logs_localbkp="${vivian_logs}/localbkp"

# monitoring logs
vivian_mon_status_ok="echo WE_HAVE_FRESH_BACKUP"
vivian_mon_status_error="echo TODAY_ARCHIVE_EXISTS"
vivian_mon_status_localbkp_error="echo LOCALBKP_IS_NOT_EMPTY"
vivian_mon_status_localbkp_ok="echo LOCALBKP_IS_EMPTY"

source $vivian_root/help.sh
source $vivian_root/mysql.sh
source $vivian_root/encryption.sh
source $vivian_root/rsync.sh

function log (){

	# small function for logging

	echo "[`date +"%d.%m.%Y %T"`] $1" >> $vivian_logs_general

}

function send_mail() {
	if [ -z "$monitoring_email" ]; then return; fi
	subject=$1
	content=$2
	echo $content | mail -a "Content-Type: text/plain; charset=UTF-8" -s $subject $monitoring_email
}

function vivian_clear_logs(){

	# this function will clear vivian logs
	# and monitoring checks.

	# clear general log file
	cat /dev/null > $vivian_logs_general
	log "The log file was cleared."
}

function localbkp_clear(){

	# this function will clear localbkp
	rm -rf $vivian_localbkp/*
	log "All files in localbkp were deleted."

	# check localbkp content (for Nagios)
	localbkp_check

	# this will make log file a bit easier for reading
	log "============================================="

}

function restore_clear(){

	# this function will clear all files in restore
	rm -rf $vivian_restore/*
	log "All files in restore were deleted."

}

function localbkp_check(){

	# this function will cleck if localbkp is empty
	if find "$vivian_localbkp" -mindepth 1 -print -quit | grep -q .;

	then

		$vivian_mon_status_localbkp_error > $vivian_logs_localbkp

	else

		$vivian_mon_status_localbkp_ok > $vivian_logs_localbkp

	fi

}

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

# restore all encrypted files in a given directory
function restore_decrypt(){
	# get all files and do decryption
	for file in `find $1 -name "*.pi"`; do
		decrypt_file "$file" && rm -f "$file"
	done
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

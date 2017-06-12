#!/bin/bash

# int global
vivian_root=$(readlink -f `dirname $0`)

vivian_version="1.0"
vivian_readme="${vivian_root}/readme"

# vivian mysql username/password
vivian_mysql_username="xxxxxxxxxx"
vivian_mysql_password="********************"

encryption_password="********************"

backup_private_key="-----BEGIN RSA PRIVATE KEY-----
################################################################
................................................................
################################################################
-----END RSA PRIVATE KEY-----"

# remote server paths
vivian_remote_main="/backup/"

# remote connection
backup_username="backup"
backup_key="${vivian_root}/master_key"

# backup servers
backup_master="backup@master.com"
backup_secondary="backup@secondary.com"
backup_master_port="backup@master.com"
backup_secondary_port="backup@secondary.com"

# email
monitoring_email="monitoring@example.com"

source $vivian_root/.env


# colors
c_red="\033[1;31m"
c_green="\033[1;32m"
c_reset="\033[0m"

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

# encryption
vivian_encryption_file="${vivian_root}/enc_password_hidden"

# remote server paths
vivian_remote_storage="${vivian_remote_main}${this_server}"
vivian_remote_storage_files="${vivian_remote_storage}/files"

# monitoring logs
vivian_mon_status_ok="echo WE_HAVE_FRESH_BACKUP"
vivian_mon_status_error="echo TODAY_ARCHIVE_EXISTS"
vivian_mon_status_localbkp_error="echo LOCALBKP_IS_NOT_EMPTY"
vivian_mon_status_localbkp_ok="echo LOCALBKP_IS_EMPTY"

function show_help(){

	# Help section

	echo "Available options:"
	echo
	echo
	echo -e "${c_green}--mysql-clean${c_reset}		- will dump all MySQL databases ${c_red}wthout${c_reset} encryption step"
	echo -e "${c_green}--mysql-encrypt${c_reset}		- will dump all MySQL database and will ${c_red}encrypt${c_reset} them"
	echo -e "${c_green}--rsync-master${c_reset}		- will rsync databases to the ${c_red}main${c_reset} backup server"
	echo -e "${c_green}--rsync-secondary${c_reset}  	- will rsync databases to the ${c_red}secondary${c_reset} backup server"
	echo -e "${c_green}--localbkp-clear${c_reset}		- with this you can clear ${c_red}localbkp${c_reset} directory"
	echo -e "${c_green}--lokalbkp-check${c_reset}		- will check ${c_red}localbkp${c_reset} directory and will print if there are any files"
	echo -e "${c_green}--localbkp-encrypt${c_reset} 	- if you have custom files in ${c_red}localbkp${c_reset} directory, with this function you can encrypt them"
	echo -e "${c_green}--restore-decrypt${c_reset}    	- decrypt all files in ${c_red}restore${c_reset} directory"
	echo -e "${c_green}--restore-clear${c_reset}		- all files in ${c_red}restore${c_reset} will be deleted"
	echo -e "${c_green}--files${c_reset}			- will backup files/directories from each line in ${c_red}files.conf${c_reset} without encryption"
	echo -e "${c_green}--clear-logs${c_reset}		- this will clear ${c_red}all${c_reset} vivian logs and monitoring checks"
	echo
	echo
}

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

function dump_mysql_databases() {
	# list all databases. exclude some meta.
	databases=`mysql --user=$vivian_mysql_username --password=$vivian_mysql_password -e "SHOW DATABASES" | grep -E -v "^(Database|information_schema|mysql|performance_schema|phpmyadmin)$"`

	# dump databases
	for db in $databases; do
		log "Dumping database: $db"
		mysqldump --force --opt --user=$vivian_mysql_username --password=$vivian_mysql_password --databases $db | gzip > $vivian_localbkp/$current_date-$db.sql.gz
	done
}

function mysql_clean(){

	dump_mysql_databases

	log "The databases are exported."
	send_mail "$this_server: backups for $current_date are generated" "The backups (unsecured) for $current_date are generated."
	$vivian_mon_status_ok > $vivian_logs_mon

}

function mysql_encrypt(){

	dump_mysql_databases

	log "The databases are exported but not encrypted."
	send_mail "$this_server: backups for $current_date are generated" "The backups for $current_date are generated and secured."
	$vivian_mon_status_ok > $vivian_logs_mon

	###
	#
	# Encryption part:
	#
	# When all databases are exported and we have encryption file
	# the next step will be to compress every .sql file.
	#
	# The fun part is that all encrypted files will be called:
	#
	#	$currentdate-databasename.pi
	#
	# When we need to restore some database, we need only .pi file.
	# The restoration is automated and we don't need anything else.
	#
	###

	find $vivian_localbkp -name "*.sql.gz" -exec encrypt_file {} \; -delete

	log "All unencrypted databases are now secured."

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

# this function will restore all encrypted databases in $vivian_restore folder
function restore_decrypt(){
	# get all files and do decryption
	find $vivian_restore -name "*.pi" -exec decrypt_file {} \; -delete
}

function master_key_create(){

	# let's create our key for rsync

	echo "$backup_private_key" > $backup_key

	chmod 600 $backup_key
	log "The master key is created"

}

function master_key_destroy(){

	# delete master_key
	rm -f $backup_key
	log "The master key was deleted"
}

function encrypt_file() {
	infile=$1
	outfile=$infile.pi
	openssl_file $infile $outfile
}

function decrypt_file() {
	infile=$1
	outfile=${infile/.pi/}
	openssl_file $infile $outfile -d
}

function openssl_file() {
	encryption_file_create
	openssl aes-256-cbc $3 -in $1 -out $2 -pass file:$vivian_encryption_file
	encryption_file_destroy
}

# this function will create the encryption file
function encryption_file_create(){
	echo $encryption_password > $vivian_encryption_file
	log "The encryption file is created."
}

# this function will destroy the encryption file
function encryption_file_destroy(){
	rm -f $vivian_encryption_file
	log "The encryption file was deleted."
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

function rsync_to_storage(){

	# create master key
	master_key_create

	cd $vivian_root

	host=$1
	port=$2

	# let's move databases
	rsync -avz --progress -e "ssh -p $port -i $backup_key" ${vivian_localbkp}/*.pi $host:$vivian_remote_storage

	# if we have any files, we will move them
	if [ -d "$vivian_localbkp_files" ]; then
		rsync -avz --progress -e "ssh -p $port -i $backup_key" ${vivian_localbkp_files} $host:$vivian_remote_storage_files
	else
		log "We don't have files for backup. Skip."
	fi

	# delete master key
	master_key_destroy

}

for arg in "$@"; do
case "$arg" in
	--mysql-clean|mysql-clean)
		mysql_clean
	;;
	--mysql-encrypt|mysql-encrypt)
		mysql_encrypt
	;;
	--rsync-master|rsync-master)
		rsync_to_storage "$backup_username@$backup_master" $backup_master_port
	;;
	--rsync-secondary|rsync-secondary)
		rsync_to_storage "$backup_username@$backup_secondary" $backup_secondary_port
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
		restore_decrypt
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
		show_help
esac
done

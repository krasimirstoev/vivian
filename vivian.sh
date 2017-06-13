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
# remote_storages is an array of strings of the form
#    "username hostname port"
declare -a remote_storages

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

source $vivian_root/help.sh

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

	storage_dir=$1
	# dump databases
	for db in $databases; do
		log "Dumping database: $db"
		mysqldump --force --opt --user=$vivian_mysql_username --password=$vivian_mysql_password --databases $db | gzip > $storage_dir/$current_date-$db.sql.gz
	done
}

function mysql_clean(){

	storage_dir=$1
	dump_mysql_databases $storage_dir

	log "The databases are exported."
	send_mail "$this_server: backups for $current_date are generated" "The backups (unsecured) for $current_date are generated."
	$vivian_mon_status_ok > $vivian_logs_mon

}

function mysql_encrypt(){

	storage_dir=$1
	dump_mysql_databases $storage_dir

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

	for file in `find $storage_dir -name "*.sql.gz"`; do
		encrypt_file "$file" && rm -f "$file"
	done

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

# restore all encrypted files in a given directory
function restore_decrypt(){
	# get all files and do decryption
	for file in `find $1 -name "*.pi"`; do
		decrypt_file "$file" && rm -f "$file"
	done
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

function rsync_to_storages() {
	for storage_def in "${remote_storages[@]}"; do
		parts=($storage_def)
		rsync_to_storage "${parts[0]}@${parts[1]}" ${parts[2]}
	done
}

function rsync_to_storage(){
	host=$1
	port=$2

	# let's move databases
	rsync_files $host:$vivian_remote_storage $port $backup_key "${vivian_localbkp}/*.pi"

	# if we have any files, we will move them
	if [ -d "$vivian_localbkp_files" ]; then
		rsync_files $host:$vivian_remote_storage_files $port $backup_key "${vivian_localbkp_files}"
	fi
}

function rsync_files() {
	remote_path=$1
	remote_ssh_port=$2
	ssh_key=$3
	local_files=$4
	rsync_key_create $ssh_key
	rsync -avz --progress -e "ssh -p $remote_ssh_port -i $ssh_key" $local_files $remote_path
	rsync_key_destroy $ssh_key
}

function rsync_key_create(){
	key_file=$1
	echo "$backup_private_key" > $key_file
	chmod 600 $key_file
}

function rsync_key_destroy(){
	rm -f $1
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

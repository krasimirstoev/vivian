#!/bin/bash

# int global
vivian_root=`dirname $0`/

vivian_version="1.0"
vivian_readme="${vivian_root}readme"

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
backup_key="${vivian_root}master_key"

# backup servers
backup_master="backup@master.com"
backup_secondary="backup@secondary.com"
backup_master_port="backup@master.com"
backup_secondary_port="backup@secondary.com"

# email
monitoring_email="monitoring@example.com"

source $vivian_root/.env


# random hash
random_hash=`</dev/urandom tr -dc '1234567890qwertyuiopasdfghjklzxcvbnm' | head -c4; echo ""`

# colors
c_red="\033[1;31m"
c_green="\033[1;32m"
c_reset="\033[0m"

# some globals
this_server=`hostname`
current_date=`date +%Y-%m-%d`

# vivian file backup
vivian_files_conf="${vivian_root}files.conf"

# global paths
vivian_localbkp="${vivian_root}localbkp/" # storage path
vivian_localbkp_files="${vivian_localbkp}files/" # files/dirs
vivian_restore="${vivian_root}restore/" # restore

# log files
vivian_logs="${vivian_root}logs/"
vivian_logs_general="${vivian_logs}general.log"
vivian_logs_mon="${vivian_logs}last_backup"
vivian_logs_localbkp="${vivian_logs}localbkp"

# encryption
vivian_encryption_file="${vivian_root}enc_password_hidden"

# remote server paths
vivian_remote_storage="${vivian_remote_main}${this_server}/"
vivian_remote_storage_files="${vivian_remote_storage}files/"

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

function vivian_clear_logs(){

	# this function will clear vivian logs
	# and monitoring checks.

	# clear general log file
	cat /dev/null > $vivian_logs_general
	log "The log file was cleared."
}

function mysql_clean(){

	# firstly check if we have some backups in localbkp directory

	if find "$vivian_localbkp" -mindepth 1 -print -quit | grep -q .;

	then

	# if we have some backups, interupt the proccess
	log "Error! We have backups for today. Exit!"
	echo "The backup for $current_date already exist! Check server vivian, system logs and monitoring services." | mail -a "Content-Type: text/plain; charset=UTF-8" \
	 -s "$this_server: problem with vivian backups for $current_date" $monitoring_email

	$vivian_mon_status_error > $vivian_logs_mon

	sleep 2

	exit

	else

	# this will dump all mysql database and will not encrypt them

	log "localbkp folder is empty and this is ok"

	# list all databases. exclude some meta.
	databases=`mysql --user=$vivian_mysql_username --password=$vivian_mysql_password -e "SHOW DATABASES;" | tr -d "| " | grep -v Database | grep -v ^information_schema$ | \
	grep -v ^mysql$ | grep -v ^performance_schema$ | grep -v ^phpmyadmin$`

	# dump databases
	for db in $databases; do
		if [[ "$db" != "information_schema" ]] && [[ "$db" != _* ]] ; then
			log "Dumping database: $db"
			mysqldump --force --opt --user=$vivian_mysql_username --password=$vivian_mysql_password --databases $db > $vivian_localbkp/$current_date-$db.sql

			# gzip exported databases
			gzip $vivian_localbkp*$db.sql
		fi

	done

	log "The databases are exported."
	echo "The backups (unsecured) for $current_date are generated." | mail -a "Content-Type: text/plain; charset=UTF-8" \
	-s "$this_server: backups for $current_date are generated" $monitoring_email
	$vivian_mon_status_ok > $vivian_logs_mon

	fi
}

	######
	#
	# the file enc_password_hiden are encrypted with blowfish.
	# inside is hidden our password, named as a soup.
	# this file will be created every time before encryption
	# and will be deleted after that.
	#
	# to prevent bus-factor situation only Berlioz and Borislav
	# will know what is the secret.
	#
	######

function encryption_file_create(){

	# this function will create the encryption file
	cd $vivian_root
	touch $vivian_encryption_file
	echo $encryption_password > $vivian_encryption_file
	log "The encryption file is created."

}

function encryption_file_destroy(){

	# this function will destroy the encryption file
	rm -f $vivian_encryption_file
	log "The encryption file was deleted."

}

function mysql_encrypt(){

	encryption_file_create

	log "The crypto file was created."

	# firstly check if we have some backups in localbkp directory

	if find "$vivian_localbkp" -mindepth 1 -print -quit | grep -q .;

	then

	# if we have some backups, interupt the proccess

	log "Error! We have backups for today. Exit!"

	echo "The backup for $current_date already exist! Check server vivian, system logs and monitoring services." | mail -a "Content-Type: text/plain; charset=UTF-8" \
	 -s "$this_server: problem with vivian backups for $current_date" $monitoring_email

	$vivian_mon_status_error > $vivian_logs_mon

	encryption_file_destroy

	log "After the backup failure, the crypto file was deleted."

	sleep 2

	exit

	else

	# this will dump all mysql database and will not encrypt them

	log "localbkp folder is empty and this is ok"

	# list all databases. exclude some meta.
	databases=`mysql --user=$vivian_mysql_username --password=$vivian_mysql_password -e "SHOW DATABASES;" | tr -d "| " | grep -v Database | grep -v ^information_schema$ | \
	grep -v ^mysql$ | grep -v ^performance_schema$ | grep -v ^phpmyadmin$`

	# dump databases
	for db in $databases; do
		if [[ "$db" != "information_schema" ]] && [[ "$db" != _* ]] ; then
			log "Dumping database: $db"
			mysqldump --force --opt --user=$vivian_mysql_username --password=$vivian_mysql_password --databases $db > $vivian_localbkp/$current_date-$db.sql

			# gzip exported databases
			#gzip $vivian_localbkp*$db.sql
		fi
	done

	log "The databases are exported but not encrypted."
	echo "The backups for $current_date are generated and secured." | mail -a "Content-Type: text/plain; charset=UTF-8" \
	-s "$this_server: backups for $current_date are generated" $monitoring_email
	$vivian_mon_status_ok > $vivian_logs_mon

	fi

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

	cd $vivian_localbkp

	pure_databases_list=$(find . -name "*.sql" | cut -d"/" -f2)

	for i in $pure_databases_list
	do

		openssl aes-256-cbc -in $i -out $i.pi -pass file:$vivian_encryption_file

	done

	log "All unencrypted databases are now secured."

	# when .sql files were encrypted, let's delete them

	rm -f ${vivian_localbkp}*.sql

	# delete the encryption file

	encryption_file_destroy

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

	# first of all, we will create the crypto file
	encryption_file_create

	# when the file is created, let's create localbkp.tar.gz
	# and move it to localbkp/

	cd $vivian_root

	tar -zcvf $current_date-$this_server-localbkp.tar.gz $vivian_localbkp

	mv $current_date-$this_server-localbkp.tar.gz $vivian_localbkp

	# let's encrypt this archive

	cd $vivian_localbkp

	openssl aes-256-cbc -in $current_date-$this_server-localbkp.tar.gz -out $current_date-$this_server-localbkp.tar.gz.pi -pass file:$vivian_encryption_file

	log "Custom archive of localbkp was created and secured"

	# delete the archive
	rm -f $current_date-$this_server-localbkp.tar.gz

	encryption_file_destroy

	echo "Log into server and check this backup. If folder isn't empty, the regular backup will fail." | mail -a "Content-Type: text/plain; charset=UTF-8" \
        -s "$this_server: custom localbkp was created and secured" $monitoring_email

}

function restore_decrypt(){

	# this function will restore all encrypted databases
	# in $vivian_restore folder

	# create the crypto file
	encryption_file_create

	cd $vivian_restore

	# get all files and do decryption
	encrypted_databases_list=$(find . -name "*.pi" | cut -d"/" -f2)

	for i in $encrypted_databases_list
	do

		openssl aes-256-cbc -d -in $i -out $i.fin -pass file:$vivian_encryption_file

	done

	# rename all .sql.pi to .sql
	for all_files in *.sql.pi.fin;
	do

		mv "$all_files" "`basename "$all_files" .sql.pi.fin`.sql"

	done

	# delete the crypto file
	encryption_file_destroy

	# delete all encrypted files
	rm -f ${vivian_restore}*.sql.pi

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

function backup_files(){

	# if we have a line in files.conf
	# we will archive it in .tar.gz

	if [ -s "$vivian_files_conf" ];

	then


	mkdir -p $vivian_localbkp_files

	#$files_for_backup=$(cat $vivian_files_conf);

		for files in `cat $vivian_files_conf`
		do
			tar -zcvf ${vivian_localbkp_files}${current_date}-files.tar.gz $files >> /dev/null
		done


	else

	log "There are no files for backup. Skip."

	fi
}

function rsync_to_master(){

	# create master key
	master_key_create

	cd $vivian_root

	# create needed directory on remote server
	#ssh ssh -p $backup_master_port -i master_key $backup_username@$backup_master "mkdir -p $vivian_remote_storage"

	# let's move databases
	rsync -avz --progress -e "ssh -p $backup_master_port -i master_key" ${vivian_localbkp}*.pi $backup_username@$backup_master:$vivian_remote_storage

	# if we have any files, we will move them

	if [ -d "$vivian_localbkp_files" ];

	then

		rsync -avz --progress -e "ssh -p $backup_master_port -i master_key" ${vivian_localbkp_files} $backup_username@$backup_master:$vivian_remote_storage_files

	else

		log "We don't have files for backup. Skip."

	fi

	# delete master key
	master_key_destroy

}

function rsync_to_secondary(){

	# create master key
	master_key_create

	cd $vivian_root

	# create needed directory on remote server
	##ssh ssh -p $backup_secondary_port -i master_key $backup_username@$backup_secondary "mkdir -p $vivian_remote_storage"

	# let's move databases
	rsync -avz --progress -e "ssh -p $backup_secondary_port -i master_key" ${vivian_localbkp}*.pi $backup_username@$backup_secondary:$vivian_remote_storage

	# if we have any files, we will move them

	if [ -d "$vivian_localbkp_files" ];

	then

	rsync -avz --progress -e "ssh -p $backup_secondary_port -i master_key" ${vivian_localbkp_files} $backup_username@$backup_secondary:$vivian_remote_storage_files

	else

		log "We don't have files for backup. Skip."

	fi

	# delete master key
	master_key_destroy

}

case "$1" in
	--mysql-clean)
		mysql_clean
	;;
	--mysql-encrypt)
		mysql_encrypt
	;;
	--rsync-master)
		rsync_to_master
	;;
	--rsync-secondary)
		rsync_to_secondary
	;;
	--localbkp-clear)
		localbkp_clear
	;;
	--localbkp-check)
		localbkp_check
	;;
	--localbkp-encrypt)
		localbkp_encrypt
	;;
	--restore-decrypt)
		restore_decrypt
	;;
	--restore-clear)
		restore_clear
	;;
	--files)
		backup_files
	;;
	--clear-logs)
		vivian_clear_logs
	;;
	*)
		show_help
esac

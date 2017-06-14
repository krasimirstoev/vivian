#!/usr/bin/env bash

function dump_mysql_databases() {
	# list all databases. exclude some meta.
	skipped="Database|information_schema|mysql|performance_schema|phpmyadmin"
	if [[ -n $skipped_databases ]]; then
		skipped=$skipped"|"${skipped_databases// /|}
	fi
	databases=`mysql --user=$vivian_mysql_username --password=$vivian_mysql_password -e "SHOW DATABASES" | grep -E -v "^(${skipped})$"`
	storage_dir=$1
	# dump databases
	for db in $databases; do
		log "Dumping database: $db"
		mysqldump --force --opt --user=$vivian_mysql_username --password=$vivian_mysql_password --databases $db | gzip > $storage_dir/$current_date-$db.sql.gz
	done
}

function mysql_clean() {

	storage_dir=$1
	dump_mysql_databases $storage_dir

	log "The databases are exported."
	send_mail "$this_server: backups for $current_date are generated" "The backups (unsecured) for $current_date are generated."
	$vivian_mon_status_ok > $vivian_logs_mon
}

function mysql_encrypt() {

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

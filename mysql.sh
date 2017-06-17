dump_mysql_databases() {
	# list all databases. exclude some meta.
	local skipped="Database|information_schema|mysql|performance_schema|phpmyadmin"
	if [[ -n $skipped_databases ]]; then
		skipped=$skipped"|"${skipped_databases// /|}
	fi
	local connection="--user=${mysql_config[username]-} --password=${mysql_config[password]-} --host=${mysql_config[host]-} --port=${mysql_config[port]-}"
	local databases=$(mysql $connection -e "SHOW DATABASES" | grep -E -v "^(${skipped})$")
	local storage_dir=$1
	cd $storage_dir
	# dump databases
	for db in $databases; do
		log "Dumping database: $db"
		mysqldump --force --opt $connection --databases $db | gzip > $current_date-$db.sql.gz
		ln -sf $current_date-$db.sql.gz latest-$db.sql.gz
	done
	cd - >/dev/null
}

mysql_clean() {

	local storage_dir=$1
	dump_mysql_databases $storage_dir

	log "The databases are exported."
	send_mail "$this_server: backups for $current_date are generated" "The backups (unsecured) for $current_date are generated."
	$vivian_mon_status_ok > $vivian_logs_mon
}

mysql_encrypt() {

	local storage_dir=$1
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

	for file in $(find $storage_dir -name "*.sql.gz"); do
		encrypt_file "$file" && rm -f "$file"
	done

	log "All unencrypted databases are now secured."
}

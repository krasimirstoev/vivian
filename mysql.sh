dump_mysql_databases() {
	# list all databases. exclude some meta.
	local skipped="Database|information_schema|mysql|performance_schema|phpmyadmin"
	if [[ -n $skipped_databases ]]; then
		skipped=$skipped"|"${skipped_databases// /|}
	fi
	local connection="--user=${mysql_config[username]-} --password=${mysql_config[password]-} --host=${mysql_config[host]-} --port=${mysql_config[port]-}"
	local databases=$(mysql $connection -e "SHOW DATABASES" | grep -E -v "^(${skipped})$")
	local storage_dir=$1
	local oldcwd=$(pwd)
	cd $storage_dir
	# dump databases
	for db in $databases; do
		cd $storage_dir
		log "Dumping database: $db"
		git_cd $db
		mysqldump --skip-dump-date $connection --databases $db | sed 's#),(#),\n(#g' > all.sql
		git_commit_and_archive
	done
	cd $oldcwd
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

	encrypt_archives_in_dir "$storage_dir"

	log "All unencrypted databases are now secured."
}

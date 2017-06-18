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
		dump_mysql_database $db "$connection"
		git_commit_and_archive
	done
	cd $oldcwd
}

dump_mysql_database() {
	local db=$1
	local connection=$2
	local no_auto_increment='s/ AUTO_INCREMENT=[0-9]*\b//g'
	mysqldump --skip-dump-date --no-data $connection --databases $db | sed "$no_auto_increment" > 000-structure.sql
	local dbtables=$(mysql $connection $db -e "show tables" | grep -v Tables_in_)
	local dbtable
	for dbtable in $dbtables; do
		mysqldump --skip-dump-date $connection $db $dbtable | sed 's#),(#),\n(#g' | sed "$no_auto_increment" > $dbtable.sql
	done
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

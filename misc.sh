# if we have a line in files.conf, we will archive it in .tar.gz
backup_files() {

	if [ -s "$vivian_files_conf" ];	then

		mkdir -p $vivian_localbkp_files
		for files in $(cat $vivian_files_conf); do
			tar -zcvf ${vivian_localbkp_files}/${current_date}-files.tar.gz $files >> /dev/null
		done

	else
		log "There are no files for backup. Skip."
	fi
}

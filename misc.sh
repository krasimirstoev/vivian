# vivian file backup
vivian_files_conf="${vivian_root}/files.conf"

# files/dirs
vivian_localbkp_files="${vivian_localbkp}/files"

# generate a tar.gz archive from all files in localbkp and encrypt it
localbkp_encrypt() {

	cd $vivian_root

	local archive_file=$current_date-$this_server-localbkp.tar.gz
	tar -zcvf $archive_file $vivian_localbkp

	mv $archive_file $vivian_localbkp

	# let's encrypt this archive
	cd $vivian_localbkp

	encrypt_file $archive_file

	log "Custom archive of localbkp was created and secured"

	# delete the archive
	rm -f $archive_file

	send_mail "$this_server: custom localbkp was created and secured" "Log into server and check this backup. If folder isn't empty, the regular backup will fail."

}

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

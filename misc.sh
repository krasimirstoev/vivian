# vivian file backup
vivian_files_conf="${vivian_root}/files.conf"

# files/dirs
vivian_localbkp_files="${vivian_localbkp}/files"

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

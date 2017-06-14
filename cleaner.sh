function localbkp_clear() {

	# this function will clear localbkp
	rm -rf $vivian_localbkp/*
	log "All files in localbkp were deleted."

	# check localbkp content (for Nagios)
	localbkp_check

	# this will make log file a bit easier for reading
	log "============================================="

}

function restore_clear() {

	# this function will clear all files in restore
	rm -rf $vivian_restore/*
	log "All files in restore were deleted."

}

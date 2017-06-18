# copy all files which are listed in a given configuration file
# to a git repository
backup_files() {
	local files_conf=$1
	local git_repo=$2

	if [[ -s "$files_conf" ]]; then

		git_cd "$git_repo"
		for files in $(cat "$files_conf"); do
			cp -R "$files" .
		done
		git_commit_and_archive

	else
		log "There are no files for backup. Skip."
	fi
}

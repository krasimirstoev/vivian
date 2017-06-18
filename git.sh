git_cd() {
	local dir=$1
	if [[ ! -d $dir ]]; then
		mkdir "$dir"
	fi
	cd "$dir"
	git init 1>/dev/null 2>&1
}

# commit changes in the current directory and create an archive in the parent directory
git_commit_and_archive() {
	if [[ $(git status --porcelain) ]]; then
		git add .
		git commit -m "dump from $(date)"
		# cleanup - TODO check if this helps with the disk usage
		git gc

		local dir=$(basename $(pwd))
		cd ..
		tar zcf "$dir.tgz" "$dir"
	fi
}

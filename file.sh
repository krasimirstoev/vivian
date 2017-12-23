# create an archive from files and directories listed in a given configuration file
backup_extra_files() {
	local files_conf=$1
	local target_dir=$2

	# check if the file exists, is not empty, and has read permissions
	if [[ ! -e "$files_conf" || ! -s "$files_conf" || ! -r "$files_conf" ]]; then
		return 1
	fi

	make_sure_dir_exits "$target_dir"
	local current_date=$(date +%Y%m%d-%H%M)
	tar Pzcf "$target_dir/$(basename $target_dir)-$current_date.tgz" --files-from "$files_conf"
	return 0
}

rotate_backups() {
	local storage_dir=$1
	for db_dir in "$storage_dir"/*; do
		rotate_backup "$db_dir"
	done
}

rotate_backup() {
	local dir=$1
	local daily_dir=$dir/daily
	local weekly_dir=$dir/weekly
	local monthly_dir=$dir/monthly

	make_sure_dir_exits "$daily_dir" "$weekly_dir" "$monthly_dir"

	local seconds_7days=604800
	local seconds_30days=2592000

	move_to_backup_if_needed "$dir" "$monthly_dir" $seconds_30days \
		|| move_to_backup_if_needed "$dir" "$weekly_dir" $seconds_7days \
		|| mv_files "$dir" "$daily_dir"

	# remove backups older than a certain threshold
	rm_older_files_from_dir "$daily_dir" 7
	rm_older_files_from_dir "$weekly_dir" 60
	rm_older_files_from_dir "$monthly_dir" 600
}

move_to_backup_if_needed() {
	local source_dir=$1
	local target_dir=$2
	local threshold_time=$3

	local now=$(date +%s)
	local last_backup_date=$(find "$target_dir" -maxdepth 1 -type f -exec stat {} --printf="%Y\n" \; | sort -n -r | head -n 1)
	local diff_seconds=$((now - last_backup_date))

	if (( $diff_seconds > $threshold_time )); then
		mv_files "$source_dir" "$target_dir"
		return 0
	fi
	return 1
}

mv_files() {
	local source_dir=$1
	local target_dir=$2
	find "$source_dir" -maxdepth 1 -type f -exec mv {} "$target_dir" \;
}

rm_older_files_from_dir() {
	local dir=$1
	local threshold_days=$2
	find "$dir" -type f -mtime +$threshold_days -delete
}

make_sure_dir_exits() {
	local dir
	for dir in "$@"; do
		if [[ ! -d "$dir" ]]; then
			mkdir -p "$dir"
		fi
	done
}

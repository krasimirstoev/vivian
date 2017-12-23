rsync_to_storages() {
	local data_dir=$1; shift
	local storages=("$@")
	for storage_def in "${storages[@]}"; do
		parts=($storage_def)
		rsync_to_storage "$data_dir" "${parts[0]}@${parts[1]}" ${parts[2]} "${parts[3]}"
	done
}

rsync_to_storage() {
	local data_dir=$1
	local host=$2
	local port=$3
	local path=$4

	# remote server paths
	local remote_path="$path/$this_server"
	local ssh_key="${program_root}/master_key"

	# security: remove all non-encrypted files before rsyncing
	find "$data_dir"/* -type f ! -name "*.pi" -delete

	rsync_key_create $ssh_key
	# first make sure that the target directory exists
	ssh -p $port -i $ssh_key "$host" mkdir -p "$remote_path"
	rsync -avz --delete --progress -e "ssh -p $port -i $ssh_key" "$data_dir/" "$host:$remote_path"
	rsync_key_destroy $ssh_key
}

rsync_key_create() {
	local key_file=$1
	echo "$backup_private_key" > $key_file
	chmod 600 $key_file
}

rsync_key_destroy() {
	rm -f $1
}

rsync_to_storages() {
	local storages=("$@")
	for storage_def in "${storages[@]}"; do
		parts=($storage_def)
		rsync_to_storage "${parts[0]}@${parts[1]}" ${parts[2]} "${parts[3]}"
	done
}

rsync_to_storage() {
	local host=$1
	local port=$2
	local path=$3

	# remote server paths
	local full_path="$path/$this_server"
	local full_path_files="${full_path}/files"
	local backup_key="${vivian_root}/master_key"

	# let's move databases
	rsync_files "$host" $port "$backup_key" "$full_path" "${vivian_localbkp}/*.pi"

	# if we have any files, we will move them
	if [ -d "$vivian_localbkp_files" ]; then
		rsync_files "$host" $port "$backup_key" "$full_path_files" "${vivian_localbkp_files}"
	fi
}

rsync_files() {
	local host=$1
	local ssh_port=$2
	local ssh_key=$3
	local remote_path=$4
	local local_files=$5
	rsync_key_create $ssh_key
	# first make sure that the target directory exists
	ssh -p $ssh_port -i $ssh_key "$host" mkdir -p "$remote_path"
	rsync -avz --progress -e "ssh -p $ssh_port -i $ssh_key" $local_files "$host:$remote_path"
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

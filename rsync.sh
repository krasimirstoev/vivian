# remote server paths
vivian_remote_storage="${vivian_remote_main}/${this_server}"
vivian_remote_storage_files="${vivian_remote_storage}/files"

# remote connection
backup_key="${vivian_root}/master_key"

function rsync_to_storages() {
	for storage_def in "${remote_storages[@]}"; do
		parts=($storage_def)
		rsync_to_storage "${parts[0]}@${parts[1]}" ${parts[2]}
	done
}

function rsync_to_storage() {
	host=$1
	port=$2

	# let's move databases
	rsync_files $host:$vivian_remote_storage $port $backup_key "${vivian_localbkp}/*.pi"

	# if we have any files, we will move them
	if [ -d "$vivian_localbkp_files" ]; then
		rsync_files $host:$vivian_remote_storage_files $port $backup_key "${vivian_localbkp_files}"
	fi
}

function rsync_files() {
	remote_path=$1
	remote_ssh_port=$2
	ssh_key=$3
	local_files=$4
	rsync_key_create $ssh_key
	rsync -avz --progress -e "ssh -p $remote_ssh_port -i $ssh_key" $local_files $remote_path
	rsync_key_destroy $ssh_key
}

function rsync_key_create() {
	key_file=$1
	echo "$backup_private_key" > $key_file
	chmod 600 $key_file
}

function rsync_key_destroy() {
	rm -f $1
}

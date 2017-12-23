vivian_encryption_file="${program_root}/enc_password_hidden"

is_function_loaded log || source logging.sh

encrypt_files() {
	local file
	for file in "$@"; do
		if [[ -e "$file" ]]; then
			encrypt_file "$file" && rm -f "$file"
		fi
	done
}

encrypt_file() {
	local infile=$1
	local outfile=$infile.pi
	openssl_file $infile $outfile
}

decrypt_files() {
	local file
	for file in "$@"; do
		if [[ -d "$file" ]]; then
			decrypt_files "$file"/*.pi
		elif [[ -e "$file" ]]; then
			decrypt_file "$file" && rm -f "$file"
		fi
	done
}

decrypt_file() {
	local infile=$1
	local outfile=${infile/.pi/}
	openssl_file $infile $outfile -d
}

openssl_file() {
	encryption_file_create
	local extra_options=${3-}
	openssl aes-256-cbc $extra_options -in "$1" -out "$2" -pass file:$vivian_encryption_file
	encryption_file_destroy
}

# this function will create the encryption file
encryption_file_create() {
	echo $encryption_password > $vivian_encryption_file
	log "The encryption file is created."
}

# this function will destroy the encryption file
encryption_file_destroy() {
	rm -f $vivian_encryption_file
	log "The encryption file was deleted."
}

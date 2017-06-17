vivian_encryption_file="${vivian_root}/enc_password_hidden"

encrypt_file() {
	local infile=$1
	local outfile=$infile.pi
	if [[ -h $infile ]]; then
		ln -s $(readlink "$infile").pi $outfile
	else
		openssl_file $infile $outfile
	fi
}

decrypt_file() {
	local infile=$1
	local outfile=${infile/.pi/}
	if [[ -h $infile ]]; then
		local target=$(readlink $infile)
		ln -s ${target/.pi/} $outfile
	else
		openssl_file $infile $outfile -d
	fi
}

openssl_file() {
	encryption_file_create
	local extra_options=${3-}
	openssl aes-256-cbc $extra_options -in $1 -out $2 -pass file:$vivian_encryption_file
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

# restore all encrypted files in a given directory
restore_decrypt() {
	# get all files and do decryption
	for file in $(find $1 -name "*.pi"); do
		decrypt_file "$file" && rm -f "$file"
	done
}

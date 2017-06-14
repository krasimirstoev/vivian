vivian_encryption_file="${vivian_root}/enc_password_hidden"

encrypt_file() {
	local infile=$1
	local outfile=$infile.pi
	openssl_file $infile $outfile
}

decrypt_file() {
	local infile=$1
	local outfile=${infile/.pi/}
	openssl_file $infile $outfile -d
}

openssl_file() {
	encryption_file_create
	openssl aes-256-cbc $3 -in $1 -out $2 -pass file:$vivian_encryption_file
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

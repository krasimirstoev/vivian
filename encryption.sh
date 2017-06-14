#!/usr/bin/env bash

vivian_encryption_file="${vivian_root}/enc_password_hidden"

if [[ -z $encryption_password ]]; then
	source $vivian_root/.env
fi

function encrypt_file() {
	infile=$1
	outfile=$infile.pi
	openssl_file $infile $outfile
}

function decrypt_file() {
	infile=$1
	outfile=${infile/.pi/}
	openssl_file $infile $outfile -d
}

function openssl_file() {
	encryption_file_create
	openssl aes-256-cbc $3 -in $1 -out $2 -pass file:$vivian_encryption_file
	encryption_file_destroy
}

# this function will create the encryption file
function encryption_file_create() {
	echo $encryption_password > $vivian_encryption_file
	log "The encryption file is created."
}

# this function will destroy the encryption file
function encryption_file_destroy() {
	rm -f $vivian_encryption_file
	log "The encryption file was deleted."
}

# restore all encrypted files in a given directory
function restore_decrypt() {
	# get all files and do decryption
	for file in `find $1 -name "*.pi"`; do
		decrypt_file "$file" && rm -f "$file"
	done
}

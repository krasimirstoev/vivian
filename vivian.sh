#!/usr/bin/env bash

vivian_root=$(readlink -f `dirname $0`)

source $vivian_root/.env

this_server=`hostname`
current_date=`date +%Y%m%d-%H%M`

# storage path
vivian_localbkp="${vivian_root}/localbkp"
# restore path
vivian_restore="${vivian_root}/restore"

source $vivian_root/help.sh
source $vivian_root/mysql.sh
source $vivian_root/encryption.sh
source $vivian_root/rsync.sh
source $vivian_root/cleaner.sh
source $vivian_root/logging.sh
source $vivian_root/misc.sh

for arg in "$@"; do
case "$arg" in
	--mysql-clean|mysql-clean)
		mysql_clean $vivian_localbkp
	;;
	--mysql-encrypt|mysql-encrypt)
		mysql_encrypt $vivian_localbkp
	;;
	--rsync|rsync)
		rsync_to_storages
	;;
	--localbkp-clear|localbkp-clear)
		localbkp_clear
	;;
	--localbkp-check|localbkp-check)
		localbkp_check
	;;
	--localbkp-encrypt|localbkp-encrypt)
		localbkp_encrypt
	;;
	--restore-decrypt|restore-decrypt)
		restore_decrypt $vivian_restore
	;;
	--restore-clear|restore-clear)
		restore_clear
	;;
	--files|files)
		backup_files
	;;
	--clear-logs|clear-logs)
		vivian_clear_logs
	;;
	*)
		show_help $arg
esac
done

if [[ -z "$1" ]]; then
	show_help
fi

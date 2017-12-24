# exit the script if somewhere is an uninitialised variable
set -o nounset
#  exit the script if any statement returns a non-true value
#set -o errexit

is_function_loaded() {
	local func_name=$1
	type $func_name &>/dev/null
}

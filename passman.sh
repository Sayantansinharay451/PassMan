#!/bin/bash
#Purpose: A simple script to generate and manage password
#Version: 1.0
#Created Date: Tue Mar 14 03:58:48 PM IST 2023
#Modified Date:
#Author: Sayantan Sinharay
# START #

# TODO - Error handling and look for edge cases

UPLINE=$(tput cuu1)
ERASELINE=$(tput el)

PACKAGE=passman
VERSION="1.0.0"
PASSMAN_DB_PATH="" # TODO
PASSMAN_DB_NAME=""
PASSMAN_MANAGER_SCHEMA_NAME=""
PASSMAN_PROFILE_DB_NAME=""

show_help() {
	echo "${PACKAGE} - "
	echo " "
	echo "${PACKAGE} [options] [flags]"
	echo " "
	echo "options:"
	echo "-h, --help                                               show brief help"
	echo "-v, --version                                            show the ${PACKAGE} version"
	echo "-s, --save     <username> <website> [flags]              saves a password along with the username and website url"
	echo "-f, --fetch    <username> <optional:website>            fetch the password for the particular username"
	echo "                                                         in case of duplicate username it will all the website associated"
	echo "-m, --modify"
	exit 0
}

show_store_password_help() {
	echo "Usage: $0 [OPTIONS]"
	echo "Generate a random password and store it in the database."
	echo ""
	echo "Usage: $(basename "$0") [-l length] [-e exclude_characters] [-s symbols] [-i include_string ] [-h]"
	echo "Options:"
	echo "  -h, --help              Show this help message and exit."
	echo "  -l, --length            Set the length of the password (default: 12)."
	echo "  -i, --include           Include the specified string in the password."
	echo "  -e, --exclude           Exclude the specified characters from the password."
	echo "  -s, --symbols           Include the specified symbols in the password."
	return 1
}

show_version() {
	echo "${VERSION}"
	exit 0
}

set_password() {
	password=$1
	while [[ -z $password ]]; do
		read -e -r -s -p "Enter your password: " password
		if [[ -z $password ]]; then
			echo -e "Enter a valid password!"
			sleep 1
		fi
		echo -e "\r"
	done
	echo "$password"
}

# ! error in default value
generate_password() {

	# Default values
	local length=12
	local exclude_chars=""
	local symbols="!@#$%^&*()_+-=,./;:<>?"
	local include_string=""

	# Parse command line arguments
	while [[ $# -gt 0 ]]; do
		flags="$1"

		case $flags in
		-l | --length)
			shift
			length="$1"
			shift
			;;
		-i | --include)
			shift
			include_string="$1"
			shift
			;;
		-e | --exclude)
			shift
			exclude_chars="$1"
			shift
			;;
		-s | --symbols)
			shift
			symbols="$1"
			shift
			;;
		*)
			echo "Invalid option: $1"
			echo "Use $0 --help to see the available options."
			return 1
			;;
		esac
	done
	CHARSET='A-Za-z0-9'

	if [[ ! -z "$symbols" ]]; then
		CHARSET="$CHARSET$symbols"
	fi

	# create regex pattern for exclusion
	exclusion_pattern='['"$exclude_chars"']'

	# check if include string is present in the character set
	include_pattern=$(echo "$include_string" | awk -v CS="$CHARSET" '$0 ~ "[" CS "]" { printf("%s\n", $0) }')

	# generate password
	while true; do
		password=$(tr -cd "$CHARSET" </dev/urandom | head -c $(($length - ${#include_string})) 2>/dev/null)
		if [[ -n $symbols ]]; then
			password=$(echo "$password$symbols" | fold -w1 | shuf | tr -d '\n')
		fi
		if [[ -n "$include_string" ]]; then
			position=$((RANDOM % ($length - ${#include_string})))
			password="${password:0:$position}${include_string}${password:$position}"
		fi
		if [[ ! "$password" =~ $exclusion_pattern ]] && { [[ -z "$include_string" ]] || [[ "$password" =~ $include_pattern ]]; }; then
			echo "$password"
			return 0
		fi
	done
	return 1
}

encrypt_password() {
	encrypted_password=$(echo "$password" | openssl enc -aes-256-cbc -a -salt)
	echo "${encrypted_password}"
	return 0
}

#  decrypt_password() {

# }

set_additional_details() {
	read -r -p "Do you want to add additional details [y/n]: " choice
	case $choice in
	y | Y)
		read -r -p "Enter a title: " title
		read -r -p "Enter any description: " description
		echo "$title $description"
		return 0
		;;
	n | N)
		echo "Ok!"
		return 0
		;;
	*)
		echo "error"
		return 1
		;;
	esac
}

#  get_additional_details() {

# }

modify_additional_details() {
	read -r -p "Enter the updated title: " title
	read -r -p "Enter the updated description: " description
	echo "$title $description"
	return 0
}

# modify_username() {}

store_password() {
	echo "$@"
}

# ! changes required
if [ $# -eq 0 ]; then
	echo "Usage: passman [store|]" #! changes required
	exit 1
fi

while [[ $# -gt 0 ]]; do
	options=$1
	case $options in
	-h | --help)
		shift
		show_help
		;;
	-v | --version)
		shift
		show_version
		;;
	-s | --store)
		shift

		if [[ $1 == '-h' || $1 == '--help' ]]; then
			show_store_password_help
		fi

		if [ $# -lt 3 ]; then
			echo "Usage: passman --store <username> <website> <password> [flags]" #! changes required
			echo "Use $0 --help to see the available options."
			exit 1
		else
			username=$1
			shift
			website=$1
			shift
			if [[ $1 == "-p" || $1 == "--password" ]]; then
				shift
				password=$(set_password "$@")
			elif [[ $1 == "-g" || $1 == "--generate" ]]; then
				shift
				if [[ $1 == "-h" || $1 == "--help" ]]; then
					show_generate_password_help
				fi
				confirmed=false
				while ! $confirmed; do
					password=$(generate_password "$@") || {
						echo "$password"
						exit 1
					}
					echo "$password"
					read -r -p "Do like to confirm the generated password [y/n]: " confirmation
					echo -e "$UPLINE$ERASELINE$UPLINE$ERASELINE\c"
					case $confirmation in
					y | Y)
						confirmed=true
						;;
					n | N)
						confirmed=false
						;;
					esac
				done
			else
				echo "Invalid option: $1"
				echo "Use $0 --help to see the available options."
				exit 1
			fi
			password=$(encrypt_password "$password")
			echo "$password"
			details=$(set_additional_details) && {
				read -r title description <<<"$details"
			}
			details=$(set_additional_details) || {
				echo "$details"
			}
			store_password "$username $website $password $title $description"
		fi
		;;
	*)
		echo "Invalid option: $1"
		echo "Use $0 --help to see the available options."
		exit 1
		;;
	esac
done

create_profile() {
	read -r -p "Enter name for new profile: " profile_name
	read -r -p -s "Enter a new password for your profile: " profile_password

	echo -en "\rCreating new table for profile $profile_name..."
	# Create a new table for the profile
	sqlite3 "$PASSMAN_DB_PATH"/"$PASSMAN_DB_NAME".db <<EOF
	CREATE TABLE ${profile_name}_${PASSMAN_PROFILE} (
		website TEXT PRIMARY KEY, 
		user_name TEXT, 
		password TEXT
		title TEXT,
		description TEXT
	);
EOF

	profile_id=$(sqlite3 "$PASSMAN_DB_PATH"/"$PASSMAN_DB_NAME".db "select lower(hex(randomblob(2)));")

	sqlite3 "$PASSMAN_DB_PATH"/"$PASSMAN_DB_NAME".db <<EOF
	INSERT INTO ${PASSMAN_MANAGER_SCHEMA_NAME} (profile_id, profile_name) VALUES ('$profile_id', $profile_name');
EOF

	# Save the encryption key for the profile
	encryption_key=$("${profile_password}" | openssl enc -aes-256-cbc -salt -a -pass pass:"${profile_id}")

	sqlite3 "$PASSMAN_DB_PATH"/"$PASSMAN_DB_NAME".db <<EOF
	INSERT INTO ${PASSMAN_MANAGER_SCHEMA_NAME} (encryption_key) VALUES ('$encryption_key');
EOF

	sleep 2
	echo "Profile '${profile_name}' created."
}

# checks if passman is installed or not
system_check() {
	echo " "
}

access_profile() {
	echo " "
}

switch_profile() {
	echo ""
}

see_current_profile() {
	echo ""
}

init() {
	if [[ -z $PASSMAN_DB_PATH ]]; then
		# *Give the exact path
		# *want to give relative path
		read -r -p "Enter the path where you want to store your database (default path is /bin/): " new_db_path
		PASSMAN_DB_PATH=$new_db_path

		# export the dp path
		echo -en "\rCreating new database for Passman"
		sqlite3 "$PASSMAN_DB_PATH"/"$PASSMAN_DB_NAME".db <<EOF
			CREATE TABLE ${PASSMAN_MANAGER_SCHEMA_NAME} (
				profile_id CHAR(4) PRIMARY KEY,
				profile_name TEXT
				encrypt_key TEXT
			);
EOF
		sleep 1
		echo -en "\rDatabase and table created successfully."
		create_profile
	else
		echo "Passman already exists in your system!"
		echo "To create new profile use --profile to create one"
		# !Some more message
	fi
	exit 0
}
# END #

# *need a trigger to generate unique id for each user
# CREATE TRIGGER AutoGenerateGUID
# AFTER INSERT ON tblUsers
# FOR EACH ROW
# WHEN (NEW.UserAccountID IS NULL)
# BEGIN
#    UPDATE tblUsers SET UserAccountID = (select hex( randomblob(4)) || '-' || hex( randomblob(2))
#              || '-' || '4' || substr( hex( randomblob(2)), 2) || '-'
#              || substr('AB89', 1 + (abs(random()) % 4) , 1)  ||
#              substr(hex(randomblob(2)), 2) || '-' || hex(randomblob(6)) ) WHERE rowid = NEW.rowid;
# END;

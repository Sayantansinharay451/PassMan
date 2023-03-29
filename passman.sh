#!/bin/bash
#Purpose: A simple script to generate and manage password
#Version: 1.0
#Created Date: Tue Mar 14 03:58:48 PM IST 2023
#Modified Date:
#Author: Sayantan Sinharay
# START #

PACKAGE=passman
VERSION="1.0.0"

function show_help() {
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

function show_version() {
  echo "${VERSION}"
  exit 0
}

function set_password() {
  read -e -r -s -p "Enter your password: " password
  echo -e "\r"
  echo "$password"
}

# ! error in default value
function generate_password() {

  help() {
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
    exit 0
  }

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
    -h | --help)
      help
      ;;
    *)
      echo "Invalid option: $1"
      echo "Use $0 --help to see the available options."
      exit 1
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
      exit 0
    fi
  done
}

function encrypt_password() {
  encrypted_password=$(echo "$password" | openssl enc -aes-256-cbc -a -salt)
  echo "${encrypted_password}"
}

# function decrypt_password() {

# }

function set_additional_details() {
  read -r -p "Do you want to add additional details [y/n]: " choice
  case $choice in
  y | Y)
    read -r -p "Enter a title: " title
    read -r -p "Enter any description: " description
    echo "$title $description"
    ;;
  n | N)
    echo "Ok!"
    ;;
  *)
    echo "error"
    ;;
  esac
}

# function get_additional_details() {

# }

function modify_additional_details() {
  read -r -p "Enter the updated title: " title
  read -r -p "Enter the updated description: " description
  echo "$title $description"
}

function store_password() {
  echo "$@"
}

if [ $# -eq 0 ]; then
  echo "Usage: ./password_manager.sh [generate|store|get|help]" #! changes required
  exit 1
fi

UPLINE=$(tput cuu1)
ERASELINE=$(tput el)

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
  -s | --save)
    shift
    if [ $# -lt 3 ]; then
      echo "Usage: ./password_manager.sh store <username> <website> <password> [notes]" #! changes required
      exit 1
    else
      username=$1
      shift
      website=$1
      shift
      if [[ $# -gt 0 ]]; then
        flags=$1
        password=""
        case $flags in
        -p | --password)
          shift
          password=$(set_password)
          shift

          ;;
        -g | --generate)
          shift
          confirmed=false
          while ! $confirmed; do
            password=$(generate_password "$@")
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
          shift
          break
          ;;
        *)
          echo "Use "
          exit 1
          ;;
        esac
      else
        echo "Check Usage"
      fi
      # password=$(encrypt_password "$password")
      title=""
      description=""
      read -r title description <<<"$(set_additional_details)"
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
# END #

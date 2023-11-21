#!/usr/bin/env bash

set -Eeuo pipefail

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' \
    ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' \
    CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

setup_colors

VER="1.0.0"

# print version
msg "${GREEN}Script Ver${RED} ${VER}${NOFORMAT} .. "

echo "1)"
echo "2) "
echo "Choose an number:" | tr -d '\n'
read CHOOSE_CMD 
case $CHOOSE_CMD in
  1)
  ;;
  2)
  ;;
  *) 
    echo "You did not choose!"
    ;;
esac
#! /usr/bin/env bash
set -euo pipefail

function parameterize() {
    local input="${*:-$(cat -)}"
    echo "${input// /_}"
}

function unparameterize() {
    local input="${*:-$(cat -)}"
    echo "${input//_/ }"
}

function to_params() {
    local IFS=','
    local input="${*:-$(cat -)}"
    read -r -a array <<<"$input"
    local result=""
    for item in "${array[@]}"; do
        result+="$(parameterize "$item"),"
    done
    echo "${result%,}"
}

function from_params() {
    local IFS=','
    if [[ -n "$1" ]]; then
        local input="${*:-$(cat -)}"
    else
        local input="$1"
    fi
    read -r -a array <<<"$input"
    echo "${array[@]}"
}

msg() {
    echo >&2 -e "${1-}"
}

die() {
    local msg=$1
    local code=${2-1} # default exit status 1
    msg "$msg"
    exit "$code"
}

# ARR=("1 2" "3 4" "5 6")
# from_params "1,2,3"
# from_params <<<"1_2,2_3,3_4,4_5" | unparameterize
# to_params "1 2 3"
# to_params <<<"1 2 3 4"
# to_params "${ARR[@]}"
# to_params "${ARR[@]}" | from_params
# to_params "${ARR[@]}" | from_params | unparameterize

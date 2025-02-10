#! /usr/bin/env bash
set -euo pipefail

export DATA_DIR="data/submissions"
export REPORT_FILE="output/report.md"
export IMAGE_DIR="output/images"

usage() {
    cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] [-f] -u uuid arg1 [arg2...]
Generate a vulnerability report based on a single submission or targets
Available options:
-h, --help      Print this help and exit
-v, --verbose   Print script debug info
-u, --uuid      Submission UUID to capture
-t, --targets   Targets to generate a report on
EOF
    exit
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

parse_params() {
    TARGETS=''
    UUIDS=()

    while :; do
        case "${1-}" in
        -h | --help) usage ;;
        -v | --verbose) set -x ;;
        -t | --targets)
            TARGETS="${2-}"
            shift
            ;;
        -u | --uuid)
            UUIDS+=("${2-}")
            shift
            ;;
        -?*) die "Unknown option: $1" ;;
        *) break ;;
        esac
        shift
    done

    # args=("$@")
    # # check required params and arguments
    # [[ -z "${param-}" ]] && die "Missing required parameter: param"
    # [[ ${#args[@]} -eq 0 ]] && die "Missing script arguments"

    return 0
}

parse_params "$@"

if [[ -z $TARGETS && ${#UUIDS[@]} -eq 0 ]]; then
    if [[ ! -f data/targets/all.json ]]; then
        msg "Fetching targets"
        ./scripts/bugcrowd/targets.sh
        msg "Done fetching targets"
    fi

    TARGETS=$(
        jq -r .[].attributes.name data/targets/all.json |
            sort |
            fzf --multi --prompt='Select targets' |
            tr '\n' ',' |
            sed 's/,$//'
    )
fi

msg "Fetching submission(s) for $TARGETS ${UUIDS[*]}"
./scripts/bugcrowd/submissions.sh "$TARGETS" "${UUIDS[@]}"
msg "Done fetching submission(s)"

msg "Generating initial report"
./scripts/reporting/report.sh "$TARGETS"
msg "Done generating initial report"

msg "Fetching image assets and replacing in report"
./scripts/reporting/images.sh "$TARGETS"
msg "Done image assets"

msg "Report is finalized"

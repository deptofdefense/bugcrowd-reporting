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
-t, --target    Target to generate a report on
-s, --state     Submission states to filter by (default: unresolved,resolved,informational)
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
    _TARGETS=()
    _UUIDS=()
    _STATES=()

    TARGETS=''
    UUIDS=''
    STATES="unresolved,resolved,informational"

    while :; do
        case "${1-}" in
        -h | --help) usage ;;
        -v | --verbose) set -x ;;
        -t | --target)
            _TARGETS+=("${2-}")
            shift
            ;;
        -u | --uuid)
            _UUIDS+=("${2-}")
            shift
            ;;
        -s | --state)
            _STATES+=("${2-}")
            shift
            ;;
        -?*) die "Unknown option: $1" ;;
        *) break ;;
        esac
        shift
    done

    if [[ ${#_STATES[@]} -gt 0 ]]; then
        STATES=$(echo "${_STATES[@]}" | tr ' ' ',')
    fi

    if [[ ${#_TARGETS[@]} -gt 0 ]]; then
        TARGETS=$(echo "${_TARGETS[@]}" | tr ' ' ',')
    fi

    if [[ ${#_UUIDS[@]} -gt 0 ]]; then
        UUIDS=$(echo "${_UUIDS[@]}" | tr ' ' ',')
    fi

    return 0
}

parse_params "$@"

if [[ -z $TARGETS && -z $UUIDS ]]; then
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

msg "Fetching $STATES submission(s) for $TARGETS $UUIDS"
./scripts/bugcrowd/submissions.sh "$TARGETS" "$STATES" "$UUIDS"
msg "Done fetching submission(s)"

msg "Generating initial report"
./scripts/reporting/report.sh "$TARGETS"
msg "Done generating initial report"

msg "Fetching image assets and replacing in report"
./scripts/reporting/images.sh "$TARGETS"
msg "Done image assets"

msg "Report is finalized"

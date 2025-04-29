#! /usr/bin/env bash
set -euo pipefail

. ./scripts/reporting/utils.sh

export DATA_DIR="data/submissions"
export REPORT_FILE="output/report.md"
export IMAGE_DIR="output/images"

usage() {
    cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] [-f] -u uuid arg1 [arg2...]
Generate a vulnerability report based on a single submission or targets
Available options:
-h, --help              Print this help and exit
-v, --verbose           Print script debug info
-u, --uuid              Submission UUID to capture
-t, --target            Target to generate a report on
-s, --state             Submission states to filter by (default: unresolved,resolved,informational)
-p, --severity          Submission severities to filter by (default: 1,2,3,4,5)
-cf, --custom-field     Custom field to output in report
--skip-fetch            Skip fetching submissions
EOF
    exit
}
parse_params() {
    _TARGETS=()
    _UUIDS=()
    _STATES=()
    _SEVERITIES=()
    _CUSTOM_FIELDS=()
    SKIP_FETCH=''

    TARGETS=''
    UUIDS=''
    STATES="unresolved,resolved,informational"
    SEVERITIES=""
    CUSTOM_FIELDS=''

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
        -p | --severity)
            _SEVERITIES+=("${2-}")
            shift
            ;;
        -cf)
            _CUSTOM_FIELDS+=("${2-}")
            shift
            ;;
        --skip-fetch)
            SKIP_FETCH=1
            ;;
        -?*) die "Unknown option: $1" ;;
        *) break ;;
        esac
        shift
    done

    if [[ ${#_STATES[@]} -gt 0 ]]; then
        STATES=$(to_params "${_STATES[@]}")
    fi

    if [[ ${#_TARGETS[@]} -gt 0 ]]; then
        TARGETS=$(to_params "${_TARGETS[@]}")
    fi

    if [[ ${#_UUIDS[@]} -gt 0 ]]; then
        UUIDS=$(to_params "${_UUIDS[@]}")
    fi

    if [[ ${#_SEVERITIES[@]} -gt 0 ]]; then
        SEVERITIES=$(to_params "${_SEVERITIES[@]}")
    fi
    if [[ ${#_CUSTOM_FIELDS[@]} -gt 0 ]]; then
        CUSTOM_FIELDS=$(to_params "${_CUSTOM_FIELDS[@]}")
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

if [[ -n "$SKIP_FETCH" ]]; then
    msg "Skipping fetch"
else
    msg "Fetching $STATES submission(s) for $TARGETS $UUIDS"
    mkdir -p "$DATA_DIR"
    ./scripts/bugcrowd/submissions.sh "$TARGETS" "$STATES" "$UUIDS" "$SEVERITIES"
    msg "Done fetching submission(s)"
fi

msg "Generating initial report"
./scripts/reporting/report.sh "$TARGETS" "$STATES" "$CUSTOM_FIELDS"
msg "Done generating initial report"

msg "Fetching image assets and replacing in report"
mkdir -p "$IMAGE_DIR"
./scripts/reporting/images.sh "$TARGETS"
msg "Done image assets"

msg "Generating checklist"
./scripts/reporting/checklist.sh
msg "Done generating checklist"

msg "Report and checklist are finalized"

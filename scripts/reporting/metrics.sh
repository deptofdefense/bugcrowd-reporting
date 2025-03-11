#! /usr/bin/env bash
set -euo pipefail

export DATA_DIR="data/submissions"
export REPORT_FILE="output/report.md"
export IMAGE_DIR="output/images"

usage() {
    cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] [-f] -u uuid arg1 [arg2...]
Generate metrics for any targets within a time range
Available options:
-h, --help      Print this help and exit
-v, --verbose   Print script debug info
-t, --target    Target to generate a report on
-s, --state     Submission states to filter by (default: unresolved,resolved,informational)
-p, --severity  Submission severities to filter by (default: 1,2,3,4,5)
--from          From date in format YYYY-MM-DD (default: 1 week ago)
--to            To date in format YYYY-MM-DD (default: today)
--skip-fetch    Skip fetching submissions
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
    _STATES=()
    _SEVERITIES=()

    TARGETS=''
    STATES="new,out-of-scope,not-applicable,not-reproducible,triaged,unresolved,resolved,informational"
    SEVERITIES=""
    FROM=""
    TO=""
    SKIP_FETCH=false

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
        --from)
            FROM="${2-}"
            shift
            ;;
        --to)
            TO="${2-}"
            shift
            ;;
        --skip-fetch)
            SKIP_FETCH=true
            ;;
        -?*) die "Unknown option: $1" ;;
        *) break ;;
        esac
        shift
    done

    if [[ ${#_STATES[@]} -gt 0 ]]; then
        STATES=$(tr ' ' ',' <<<"${_STATES[@]}")
    fi

    if [[ ${#_TARGETS[@]} -gt 0 ]]; then
        TARGETS=$(tr ' ' ',' <<<"${_TARGETS[@]}")
    fi
    if [[ ${#_SEVERITIES[@]} -gt 0 ]]; then
        SEVERITIES=$(tr ' ' ',' <<<"${_SEVERITIES[@]}")
    fi

    [[ -z $TO ]] && TO=$(date -u -d "today" +"%Y-%m-%d")
    [[ -z $FROM ]] && FROM=$(date -u -d "1 week ago" +"%Y-%m-%d")

    return 0
}

parse_params "$@"

if [[ -z $TARGETS && $SKIP_FETCH == false ]]; then
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

if [[ $SKIP_FETCH == false || ! -f $DATA_DIR/all.json ]]; then
    msg "Fetching $STATES submission(s) for $TARGETS"
    ./scripts/bugcrowd/submissions.sh "$TARGETS" "$STATES" "" "$SEVERITIES"
    msg "Done fetching submission(s)"
fi

if [[ $SKIP_FETCH == true ]]; then
    msg "Generating metrics from $FROM to $TO for existing targets"
else
    msg "Generating metrics from $FROM to $TO for targets: $TARGETS"
fi

SUBMISSION_COUNTS=$(
    jq \
        --arg to "$TO" \
        --arg from "$FROM" \
        '
            [.[].attributes]
            | {
                total_submitted:
                    map(select(.submitted_at >= $from and .submitted_at <= $to)) | length,
                new:
                    map(select(.state == "new")) | length,
                not_applicable:
                    map(select(.state == "not-applicable" and .last_transitioned_to_not_applicable_at >= $from and .last_transitioned_to_not_applicable_at <= $to)) | length,
                not_reproducible:
                    map(select(.state == "not-reproducible" and .last_transitioned_to_not_reproducible_at >= $from and .last_transitioned_to_not_reproducible_at <= $to)) | length,
                out_of_scope:
                    map(select(.state == "out-of-scope" and .last_transitioned_to_out_of_scope_at >= $from and .last_transitioned_to_out_of_scope_at <= $to)) | length,
                triaged:
                    map(select(.last_transitioned_to_triaged_at >= $from and .last_transitioned_to_triaged_at <= $to)) | length,
                informational:
                    map(select(.state == "informational" and .last_transitioned_to_informational_at >= $from and .last_transitioned_to_informational_at <= $to)) | length,
                unresolved:
                    map(select(.state == "unresolved" and .last_transitioned_to_unresolved_at >= $from and .last_transitioned_to_unresolved_at <= $to)) | length,
                resolved:
                    map(select(.state == "resolved" and .last_transitioned_to_resolved_at >= $from and .last_transitioned_to_resolved_at <= $to)) | length,
            }
            
        ' $DATA_DIR/all.json
)

mlr --ijson --opprint --barred cat <<<"$SUBMISSION_COUNTS"

#! /usr/bin/env bash
set -euo pipefail

TARGETS="${1:-}"
STATES="${2:-}"
UUIDS=$"${3:-}"

export ENDPOINT="/submissions"
export PARAMS=(
    --data-urlencode 'fields[target]=name,category,organization'
    --data-urlencode 'fields[submission]=title,description,state,target,bug_url,severity,file_attachments,remediation_advice,vulnerability_references'
    --data-urlencode 'fields[file_attachment]=file_name,file_type,s3_signed_url,parent'
    --data-urlencode 'include=file_attachments'
)

. ./scripts/bugcrowd/api.sh

setup

# For specified submissions by uuid
if [ -n "$UUIDS" ]; then
    ENDPOINTS=$(
        tr ',' ' ' <<<"$UUIDS" |
            sed \
                -e "s|^|$ENDPOINT/|g" \
                -e "s| | $ENDPOINT/|g"
    )
    . env_parallel.bash # Allow for PARAMS to be exported
    env_parallel fetch ::: $ENDPOINTS
else # For all submissions
    export PARAMS=(
        "${PARAMS[@]}"
        --data-urlencode "filter[state]=$STATES"
        --data-urlencode "filter[target]=$TARGETS"
        --data-urlencode 'sort=severity-asc,submitted-asc'
        --data-urlencode 'page[limit]=25'
    )
    fetch_all
fi

concatenate_data

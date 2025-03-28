#! /usr/bin/env bash
set -euo pipefail

TARGETS="${1:-}"
STATES="${2:-}"
UUIDS="${3:-}"
SEVERITIES="${4:-}"

export ENDPOINT="/submissions"
export DATA_DIR="data${ENDPOINT}"
export PARAMS=(
    --data-urlencode 'fields[target]=name,category,organization'
    --data-urlencode 'fields[submission]=title,description,state,target,bug_url,severity,file_attachments,remediation_advice,vulnerability_references,custom_fields,last_transitioned_to_informational_at,last_transitioned_to_not_applicable_at,last_transitioned_to_not_reproducible_at,last_transitioned_to_out_of_scope_at,last_transitioned_to_resolved_at,last_transitioned_to_triaged_at,last_transitioned_to_unresolved_at,submitted_at'
    --data-urlencode 'fields[file_attachment]=file_name,file_type,s3_signed_url,parent'
    --data-urlencode 'include=file_attachments,target'
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
        --data-urlencode 'filter[duplicate]=false'
    )
    if [ -n "$SEVERITIES" ]; then
        PARAMS+=(
            --data-urlencode "filter[severity]=$SEVERITIES"
        )
    fi
    fetch_all
fi

concatenate_data

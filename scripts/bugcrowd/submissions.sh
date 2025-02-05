#! /usr/bin/env bash
set -euo pipefail
TARGETS="${1:-}"
UUID="${2:-}"

HOST="https://api.bugcrowd.com"
ENDPOINT="/submissions"
PAGE=1
NEXT=""

mkdir -p "$DATA_DIR"
rm -f $DATA_DIR/*.json

# Encode "," only
function urlencode() {
    sed -e 's/,/%2c/g' <<<"$1"
}

AUTH_PARAMS=(
    -H "Accept: application/vnd.bugcrowd+json"
    -H "Authorization: Token $BUGCROWD_USERNAME:$BUGCROWD_PASSWORD"
    -H 'Bugcrowd-Version: 2024-08-15'
)

BASE_DATA_PARAMS=(
    --data-urlencode 'fields[target]=name,category,organization'
    --data-urlencode 'fields[submission]=title,description,state,target,bug_url,severity,file_attachments,remediation_advice,vulnerability_references'
    --data-urlencode 'fields[file_attachment]=file_name,file_type,s3_signed_url,parent'
    --data-urlencode 'include=file_attachments'
)

# For single submission
if [[ -n $UUID ]]; then
    ENDPOINT="${ENDPOINT}/${UUID}"
    PARAMS=(
        "${BASE_DATA_PARAMS[@]}"
    )
else # For all submissions
    PARAMS=(
        "${BASE_DATA_PARAMS[@]}"
        --data-urlencode 'filter[state]=unresolved,resolved,informational'
        --data-urlencode "filter[target]=$TARGETS"
        --data-urlencode 'sort=severity-asc,submitted-asc'
        --data-urlencode 'page[limit]=25'
    )
fi

while true; do
    echo "Fetching page $PAGE"
    if [[ -n $NEXT ]]; then
        # --globoff needed to ignore "[]" in query params
        RESP=$(
            curl -s --get --globoff --fail \
                --url "${HOST}${ENDPOINT}?${NEXT}" \
                "${AUTH_PARAMS[@]}"
        )
    else
        RESP=$(
            curl -s --get --fail \
                --url "${HOST}${ENDPOINT}" \
                "${AUTH_PARAMS[@]}" \
                "${PARAMS[@]}"
        )
    fi

    # When no count, we're done paginating
    if [[ $(jq '.meta?.count? == 0' <<<"$RESP") == "true" ]]; then
        echo "No data on page $PAGE. No more pages to fetch."
        break
    fi

    NEXT=$(jq -r '.links.next' <<<"$RESP" | sed "s/\\${ENDPOINT}?//")
    NEXT=$(urlencode "$NEXT")
    jq . <<<"$RESP" >"$DATA_DIR/$(printf "%03d\n" $PAGE).json"
    # For single submission
    if [[ $(jq '.meta?.count? == null' <<<"$RESP") == "true" ]]; then
        echo "Done fetching submission"
        break
    fi
    PAGE=$((PAGE + 1))
done

echo "Concatenating all page data"

jq -s '[.[].data] | flatten' $DATA_DIR/[0-9][0-9][0-9].json >$DATA_DIR/all.json

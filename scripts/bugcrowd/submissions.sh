#! /usr/bin/env bash
set -euo pipefail

HOST="https://api.bugcrowd.com"
ENDPOINT="/submissions"
PAGE=1
NEXT=""
TARGETS="${1:-''}"
UUID="${2:-''}"

mkdir -p "$DATA_DIR"
rm -f $DATA_DIR/*.json

# Encode "," only
function urlencode() {
    sed -e 's/,/%2c/g' <<<"$1"
}

if [[ -n $UUID ]]; then
    UUID="/${UUID}"
    PARAMS=(
        --data-urlencode 'fields[target]=name,category,organization'
        --data-urlencode 'fields[submission]=title,description,state,target,bug_url,severity,file_attachments,remediation_advice,vulnerability_references'
        --data-urlencode 'fields[file_attachment]=file_name,file_type,s3_signed_url,parent'
        --data-urlencode 'include=file_attachments'
    )
else
    PARAMS=(
        --data-urlencode 'fields[target]=name,category,organization'
        --data-urlencode 'fields[submission]=title,description,state,target,bug_url,severity,file_attachment,remediation_advice,vulnerability_references'
        --data-urlencode 'fields[file_attachment]=file_name,file_type,s3_signed_url,parent'
        --data-urlencode 'include=file_attachment'
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
        RESP=$(curl -s --get --globoff --fail \
            --url "${HOST}${ENDPOINT}?${NEXT}" \
            -H "Accept: application/vnd.bugcrowd+json" \
            -H "Authorization: Token $BUGCROWD_USERNAME:$BUGCROWD_PASSWORD" \
            -H 'Bugcrowd-Version: 2024-08-15')
    else
        RESP=$(
            curl -s --get --fail \
                --url "${HOST}${ENDPOINT}${UUID}" \
                -H "Accept: application/vnd.bugcrowd+json" \
                -H "Authorization: Token $BUGCROWD_USERNAME:$BUGCROWD_PASSWORD" \
                -H 'Bugcrowd-Version: 2024-08-15' \
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

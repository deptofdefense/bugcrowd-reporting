#! /usr/bin/env bash
set -euo pipefail

HOST="https://api.bugcrowd.com"
ENDPOINT="/submissions"
PAGE=1
NEXT=""
TARGETS="${1:?'Set targets with comma delimiter: target1.com,target2.com'}"

mkdir -p "$DATA_DIR"
rm -f $DATA_DIR/*.json

# Encode "," only
function urlencode() {
    sed -e 's/,/%2c/g' <<<"$1"
}

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
        RESP=$(curl -s --get --fail \
            --url "${HOST}${ENDPOINT}" \
            --data-urlencode 'fields[target]=name,category,organization' \
            --data-urlencode 'fields[submission]=title,description,state,target,bug_url,severity,file_attachments' \
            --data-urlencode 'fields[file_attachment]=file_name,file_type,s3_signed_url,parent' \
            --data-urlencode 'include=file_attachments' \
            --data-urlencode 'filter[state]=unresolved,resolved,informational' \
            --data-urlencode "filter[target]=$TARGETS" \
            --data-urlencode 'sort=severity-asc,submitted-asc' \
            --data-urlencode 'page[limit]=25' \
            -H "Accept: application/vnd.bugcrowd+json" \
            -H "Authorization: Token $BUGCROWD_USERNAME:$BUGCROWD_PASSWORD" \
            -H 'Bugcrowd-Version: 2024-08-15')
    fi

    # When no count, we're done paginating
    if [[ $(jq '.meta?.count? == 0' <<<"$RESP") == "true" ]]; then
        echo "No data on page $PAGE. No more pages to fetch."
        break
    fi

    NEXT=$(jq -r '.links.next' <<<"$RESP" | sed "s/\\${ENDPOINT}?//")
    NEXT=$(urlencode "$NEXT")
    jq . <<<"$RESP" >"$DATA_DIR/$(printf "%03d\n" $PAGE).json"
    PAGE=$((PAGE + 1))
done

echo "Concatenating all page data"
jq -s '[.[].data] | flatten' $DATA_DIR/*.json >$DATA_DIR/all.json

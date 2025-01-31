#! /usr/bin/env bash
set -euo pipefail

HOST="https://api.bugcrowd.com"
ENDPOINT="/targets"
PAGE=1
NEXT=""
DATA_DIR="data${ENDPOINT}"

mkdir -p "$DATA_DIR"
if [ "$(ls -A $DATA_DIR)" ]; then
    shred -u $DATA_DIR/*.json
fi

# Encode "," only
function urlencode() {
    sed -e 's/,/%2c/g' <<<"$1"
}

while true; do
    echo "Fetching page $PAGE"
    if [[ -n $NEXT ]]; then
        # --globoff needed to ignore "[]" in query params
        RESP=$(curl -s --get --globoff \
            --url "${HOST}${ENDPOINT}?${NEXT}" \
            -H "Accept: application/vnd.bugcrowd+json" \
            -H "Authorization: Token $BUGCROWD_USERNAME:$BUGCROWD_PASSWORD" \
            -H 'Bugcrowd-Version: 2024-08-15')
    else
        RESP=$(curl -s --get \
            --url "${HOST}${ENDPOINT}" \
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

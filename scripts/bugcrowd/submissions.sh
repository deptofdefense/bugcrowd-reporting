#! /usr/bin/env bash
set -euo pipefail

HOST="https://api.bugcrowd.com"
ENDPOINT="/submissions"
PAGE=1
NEXT=""

mkdir -p "data${ENDPOINT}"

# Encode "," only
function urlencode() {
    sed -e 's/,/%2c/g' <<<"$1"
}

while true; do
    if [[ -n $NEXT ]]; then
        # --globoff needed to ignore "[]" in query params
        RESP=$(curl --get --globoff \
            --url "${HOST}${ENDPOINT}?${NEXT}" \
            -H "Accept: application/vnd.bugcrowd+json" \
            -H "Authorization: Token $BUGCROWD_USERNAME:$BUGCROWD_PASSWORD" \
            -H 'Bugcrowd-Version: 2024-08-15')
    else
        RESP=$(curl --get \
            --url "${HOST}${ENDPOINT}" \
            --data-urlencode 'include=program,target' \
            --data-urlencode 'page[limit]=25' \
            --data-urlencode 'filter[state]=unresolved,resolved,informational' \
            --data-urlencode 'sort=severity-desc' \
            -H "Accept: application/vnd.bugcrowd+json" \
            -H "Authorization: Token $BUGCROWD_USERNAME:$BUGCROWD_PASSWORD" \
            -H 'Bugcrowd-Version: 2024-08-15')
    fi

    # When no count, we're done paginating
    if [[ $(jq '.meta?.count? == 0' <<<"$RESP") == "true" ]]; then
        break
    fi

    NEXT=$(jq -r '.links.next' <<<"$RESP" | sed "s/\\${ENDPOINT}?//")
    NEXT=$(urlencode "$NEXT")
    jq . <<<"$RESP" >"data${ENDPOINT}/$(printf "%03d\n" $PAGE).json"
    PAGE=$((PAGE + 1))
done

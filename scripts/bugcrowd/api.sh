#! /usr/bin/env bash
set -euo pipefail

export HOST="https://api.bugcrowd.com"

export AUTH_PARAMS=(
    -H "Accept: application/vnd.bugcrowd+json"
    -H "Authorization: Token $BUGCROWD_USERNAME:$BUGCROWD_PASSWORD"
    -H 'Bugcrowd-Version: 2024-08-15'
)

function setup() {
    mkdir -p "$DATA_DIR"
    rm -f $DATA_DIR/*.json
}

# Encode "," only
function urlencode() {
    sed -e 's/,/%2c/g' <<<"$1"
}

function fetch() {
    ENDPOINT="${1:?'Endpoint must be first param'}"
    echo "Fetching $ENDPOINT"
    RESP=$(
        curl -s --get --fail \
            --url "${HOST}${ENDPOINT}" \
            "${AUTH_PARAMS[@]}" \
            "${PARAMS[@]}"
    )
    HASH=$(sha1sum <<<"${HOST}${ENDPOINT}" | awk '{print $1}')
    jq . <<<"$RESP" >"$DATA_DIR/$HASH.json"
}

function fetch_all() {
    PAGE=1
    NEXT=""

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
        PAGE=$((PAGE + 1))
    done
}

function concatenate_data() {

    echo "Concatenating all data"
    jq -s '[.[].data] | flatten' $DATA_DIR/*.json >"$DATA_DIR/all.json"
}

export -f setup fetch_all fetch concatenate_data

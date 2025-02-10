#! /usr/bin/env bash
set -euo pipefail
shopt -s extglob

IMAGES=$(jq -s '
    [ .[].included ]
    | flatten
    | [
        .[]
        | select(.attributes.file_type == "image/png" or .attributes.file_type == "image/jpeg")
    ]
    | map({(.id): {id: .id, s3_signed_url: .attributes.s3_signed_url, file_name: .attributes.file_name, file_type: .attributes.file_type }})
    | add
' $DATA_DIR/!(all.json))

if [[ "$IMAGES" == "null" ]]; then
    echo "No images to fetch."
    exit 0
fi

IMAGES_B64=$(
    jq -r '
        to_entries |
        map(.value | @base64) |
        .[]
    ' <<<"$IMAGES"
)

function escape() {
    sed \
        -e 's|/|\\/|g' \
        -e 's|\.|\\.|g' \
        -e 's| $||g'
}

function image_ext() {
    sed 's/image\///g'
}

function fetch_image() {
    PAYLOAD=$(base64 -d <<<"$1")
    URL=$(jq -r .s3_signed_url <<<"$PAYLOAD")
    ID=$(jq -r .id <<<"$PAYLOAD")
    FILE_TYPE=$(jq -r .file_type <<<"$PAYLOAD" | image_ext)

    curl -s "$URL" \
        -o "output/images/$ID.$FILE_TYPE"
}

export -f fetch_image image_ext
parallel fetch_image ::: $IMAGES_B64

IMAGE_BASE_DIR=$(basename "$IMAGE_DIR")
grep -o -E "https://bugcrowd\.com/.*/attachments/.* " "$REPORT_FILE" | while IFS= read -r url; do
    ID="${url##*/}"
    ID="${ID%"${ID##*[![:space:]]}"}"
    ESCAPED_URL=$(escape <<<"$url")
    FILE_TYPE=$(jq -r --arg id $ID '.[$id]?.file_type?' <<<"$IMAGES" | image_ext)

    if [[ $FILE_TYPE == "null" ]]; then
        sed -i '' "s|$ESCAPED_URL||g" "$REPORT_FILE"
    else
        sed -i '' "s|$ESCAPED_URL|${IMAGE_BASE_DIR}\/${ID}\.${FILE_TYPE} |g" "$REPORT_FILE"
    fi
done

#! /usr/bin/env bash
set -euo pipefail

export DATA_DIR="data/submissions"
export REPORT_FILE="output/report.md"
export IMAGE_DIR="output/images"

if [[ ! -f data/targets/all.json ]]; then
    echo "Fetching targets"
    ./scripts/bugcrowd/targets.sh
    echo "Done fetching targets"
fi

TARGETS=$(
    jq -r .[].attributes.name data/targets/all.json |
        sort |
        fzf --multi --prompt='Select targets' |
        tr '\n' ',' |
        sed 's/,$//'
)

echo "Fetching submissions for $TARGETS"
./scripts/bugcrowd/submissions.sh "$TARGETS"
echo "Done fetching submissions"

echo "Generating initial report"
./scripts/reporting/report.sh "$TARGETS"
echo "Done generating initial report"

echo "Fetching image assets and replacing in report"
./scripts/reporting/images.sh
echo "Done image assets"

echo "Report is finalized"

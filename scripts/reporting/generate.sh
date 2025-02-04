#! /usr/bin/env bash
set -euo pipefail

export DATA_DIR="data/submissions"
export REPORT_FILE="output/report.md"
export IMAGE_DIR="output/images"

echo "Fetching all submissions"
./scripts/bugcrowd/submissions.sh "$1"
echo "Done fetching submissions"

echo "Generating initial report"
./scripts/reporting/report.sh
echo "Done generating initial report"

echo "Fetching image assets and replacing in report"
./scripts/reporting/images.sh
echo "Done image assets"

echo "Report is finalized"

#! /usr/bin/env bash
set -euo pipefail

SUBMISSIONS_BY_STATE=$(jq '
    group_by(.attributes.state) |
    map({ 
        key: .[0].attributes.state,
        value: [.[] | @base64]
    }) |
    from_entries 
' data/submissions/all.json)

if [[ -f $REPORT_FILE ]]; then
    shred -u $REPORT_FILE
fi

function sanitize() {
    sed \
        -e "s/#//g" \
        -e "s/---//g" \
        -e "s/~//g" \
        -e 's/<\?s>//g'
}

STATE_TYPES=("unresolved" "resolved" "informational")
echo '```table-of-contents
title: 
style: nestedList # TOC style (nestedList|nestedOrderedList|inlineFirstLevel)
minLevel: 0 # Include headings from the specified level
maxLevel: 0 # Include headings up to the specified level
includeLinks: true # Make headings clickable
hideWhenEmpty: false # Hide TOC if no headings are found
debugInConsole: false # Print debug info in Obsidian console
```' >>$REPORT_FILE
echo >>$REPORT_FILE

for STATE in "${STATE_TYPES[@]}"; do

    if [[ "$(jq -r --arg state $STATE '.[$state]? == null' <<<$SUBMISSIONS_BY_STATE)" == "true" ]]; then
        continue
    fi

    echo "## ${STATE^} Issues" >>$REPORT_FILE
    echo >>$REPORT_FILE

    while IFS= read -r line; do
        ITEM=$(base64 -d <<<"$line")
        ID=$(jq -r '.id' <<<"$ITEM")
        TITLE=$(jq -r '.attributes.title' <<<"$ITEM")
        SEVERITY=$(jq -r '.attributes.severity' <<<"$ITEM")
        BUG_URL=$(jq -r '.attributes.bug_url' <<<"$ITEM")
        DESCRIPTION=$(jq -r '.attributes.description' <<<"$ITEM")
        REMEDIATION_ADVICE=$(jq -r '.attributes.remediation_advice' <<<"$ITEM")
        VULNERABILITY_REFERENCE=$(jq -r '.attributes.vulnerability_references' <<<"$ITEM")

        echo "### P${SEVERITY} - $(sanitize <<<${TITLE^})" >>$REPORT_FILE
        echo >>$REPORT_FILE

        echo "ID: **${ID}**" >>$REPORT_FILE
        echo >>$REPORT_FILE

        if [[ -n $BUG_URL ]]; then
            echo "Affected URL: [$BUG_URL](${BUG_URL})" >>$REPORT_FILE
            echo >>$REPORT_FILE
        fi

        echo "#### Description" >>$REPORT_FILE
        echo "$DESCRIPTION" | sanitize >>$REPORT_FILE
        echo >>$REPORT_FILE

        echo "#### Remediation Advice" >>$REPORT_FILE
        echo "$REMEDIATION_ADVICE" | sanitize >>$REPORT_FILE
        echo >>$REPORT_FILE

        echo "#### References" >>$REPORT_FILE
        echo "$VULNERABILITY_REFERENCE" | sanitize >>$REPORT_FILE
        echo >>$REPORT_FILE

    done <<<"$(jq -r --arg state $STATE '.[$state][]' <<<$SUBMISSIONS_BY_STATE)"
done

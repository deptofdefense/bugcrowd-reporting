#! /usr/bin/env bash
set -euo pipefail

TARGETS=$(echo "$1" | tr ',' ', ')
STATE_TYPES=$(echo "$2" | tr ',' ' ')

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
        -e 's/<\?s>//g' \
        -e 's|```|\n```|g'
}

function severity_emoji() {
    EMOJI=""
    case "$1" in
    1)
        EMOJI="🔴"
        ;;
    2)
        EMOJI="🟠"
        ;;
    3)
        EMOJI="🟡"
        ;;
    4)
        EMOJI="🟢"
        ;;
    5)
        EMOJI="🔵"
        ;;
    *)
        echo "No Emoji"
        exit 1
        ;;
    esac
    echo -n "$EMOJI"
}

function format_date() {
    if [[ "$1" == "null" ]]; then
        echo ""
        return
    fi
    date -u -d "$1" '+%Y-%m-%d %H:%M UTC'
}

echo "# $TARGETS Report" >>$REPORT_FILE
echo >>$REPORT_FILE

echo "_Generated $(date "+%Y-%m-%d")_" >>$REPORT_FILE
echo >>$REPORT_FILE

echo '```table-of-contents
title: Table of Contents
style: nestedList
minLevel: 0
maxLevel: 3
includeLinks: true
hideWhenEmpty: false
debugInConsole: false
```' >>$REPORT_FILE
echo >>$REPORT_FILE

for STATE in $STATE_TYPES; do
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
        SEVERITY_EMOJI=$(severity_emoji $SEVERITY)
        SUBMITTED_AT=$(format_date "$(jq -r '.attributes.submitted_at' <<<"$ITEM")")
        TRIAGED_AT=$(format_date "$(jq -r '.attributes.last_transitioned_to_triaged_at' <<<"$ITEM")")

        echo "### $SEVERITY_EMOJI P${SEVERITY} - $(sanitize <<<${TITLE^})" >>$REPORT_FILE
        echo >>$REPORT_FILE

        echo "**Bug ID:** _${ID}_" >>$REPORT_FILE
        echo >>$REPORT_FILE

        if [[ -n $BUG_URL ]]; then
            echo "**Affected URL:** [$BUG_URL](${BUG_URL})" >>$REPORT_FILE
            echo >>$REPORT_FILE
        fi

        if [[ -n $SUBMITTED_AT ]]; then
            echo "**Submitted At:** _${SUBMITTED_AT}_" >>$REPORT_FILE
            echo >>$REPORT_FILE
        fi

        if [[ -n $TRIAGED_AT ]]; then
            echo "**Triaged At:** _${TRIAGED_AT}_" >>$REPORT_FILE
            echo >>$REPORT_FILE
        fi

        echo "#### Description ^$ID-description" >>$REPORT_FILE
        echo "$DESCRIPTION" | sanitize >>$REPORT_FILE
        echo >>$REPORT_FILE

        echo "#### Remediation Advice ^$ID-remediation" >>$REPORT_FILE
        echo "$REMEDIATION_ADVICE" | sanitize >>$REPORT_FILE
        echo >>$REPORT_FILE

        echo "#### References ^$ID-references" >>$REPORT_FILE
        echo "$VULNERABILITY_REFERENCE" | sanitize >>$REPORT_FILE
        echo >>$REPORT_FILE

    done <<<"$(jq -r --arg state $STATE '.[$state][]' <<<$SUBMISSIONS_BY_STATE)"
done

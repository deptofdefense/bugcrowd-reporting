#! /usr/bin/env bash
set -euo pipefail

jq '
    map({
        id,
        severity: .attributes.severity,
        title: .attributes.title, 
        bug_url: .attributes.bug_url,
        state: .attributes.state,
        # resolved: .attributes.state == .attributes.title,
    }) 
' data/submissions/all.json |
    mlr --j2c cat >output/checklist.csv

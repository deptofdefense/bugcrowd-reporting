
## Setup

1. Create a [Bugcrowd API Key](https://tracker.bugcrowd.com/user/api_credentials)
2. Add credential into 1Password > Employee Vault. Name it `Bugcrowd API`
    - Add username under `username` field in 1Password
    - Add password under `credential` field in 1Password
3. Run [Submissions Script](#fetching-submissions)
4. Run [Report Script](#generating-report)

## Examples

### Generating Report

#### Select Targets

When no UUID or target specified, the script will pull down all targets and allow the user to select which targets to use for the report.

```bash
op run --env-file=".env" -- ./scripts/reporting/generate.sh
```

#### By Targets

Target can be specified with the `-t | --target` argument

```bash
TARGETS='*.dds.mil,other.target.com'
op run --env-file=".env" -- ./scripts/reporting/generate.sh -t $TARGETS
```

#### Single Submission

A single submission can be pulled with the `-u | --uuid` argument

```bash
SUBMISSION_UUID="<uuid>"
op run --env-file=".env" -- ./scripts/reporting/generate.sh -u $SUBMISSION_UUID
```

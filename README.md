
## Setup

1. Create a [Bugcrowd API Key](https://tracker.bugcrowd.com/user/api_credentials)
2. Add credential into 1Password > Employee Vault. Name it `Bugcrowd API`
    - Add username under `username` field in 1Password
    - Add password under `credential` field in 1Password
3. Run [Submissions Script](#fetching-submissions)
4. Run [Report Script](#generating-report)

## Examples

### Fetching Submissions

```bash
TARGETS='*.dds.mil,other.target.com'
op run --env-file=".env" -- ./scripts/reporting/generate.sh $TARGETS
```

### Generating Report

```bash
./scripts/report.sh
```

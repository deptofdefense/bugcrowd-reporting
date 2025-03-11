
## Setup

### Dependencies

```bash
brew install 1password-cli miller fzf jq parallel
```

### 1Password

In [1Password](https://developer.1password.com/docs/cli/get-started/), enable `Settings` > `Developer` > `Integrate with 1Password CLI`

In a terminal run the following to log in with your DDS account.

```bash
op signin
```

### API Key

1. Create a [Bugcrowd API Key](https://tracker.bugcrowd.com/user/api_credentials)
2. Add credential into 1Password (API Credentials type) > Employee Vault. Name it `Bugcrowd API`
    - Add username under `username` field in 1Password
    - Add password under `credential` field in 1Password
3. Run [Report Script](#generating-report)

## Examples

### Generating Report

#### Select Targets

When no UUID or target specified, the script will pull down all targets and allow the user to select which targets to use for the report.

```bash
op run --env-file=".env" -- ./scripts/reporting/generate.sh
```

#### By Targets

Targets can be specified with the `-t | --target` argument
You can also filter the targets by their state with the `-s | --state` argument.

```bash
op run --env-file=".env" -- \
    ./scripts/reporting/generate.sh \
        -t '*.dds.mil' \
        -t 'other.target.com' \
        -s 'unresolved' \
        -s 'informational'
```

#### Submissions by UUID

Single submissions can be pulled with their UUID using the `-u | --uuid` argument

```bash
op run --env-file=".env" -- \
    ./scripts/reporting/generate.sh \
        -u "uuid1" \
        -u "uuid2"
```

### Metrics

Fetch metrics for a given date range

```bash
op run --env-file=".env" -- \
    ./scripts/reporting/metrics.sh \
        --from "2025-01-01" \
        --to "2025-02-01"
```

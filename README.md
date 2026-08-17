# tiktok-business-gateway

A Swift 6 command-line gateway for a deliberately bounded TikTok Marketing API
v1.3 surface. It ships separate reader and writer libraries and executables so
reader-only deployments do not link mutation code.

## Enabled operation surface and evidence gate

The package enables the nine fixed operations below from the reviewed official
TikTok v1.3 endpoint matrix. `catalog show` reports each operation's `enabled`
state. Enablement means the local fixed request, response, authorization, and
safety contract is implemented; it does not claim approved-app entitlement,
authenticated sandbox verification, or release readiness. Synthetic fixtures
exercise the reviewed projections without representing provider captures.

The compiled reader surface covers authorized advertisers, advertiser details, campaigns, ad
groups, ads, and BASIC synchronous reports. Resource identifiers remain
strings, list results include typed TikTok page metadata, and response bodies
are capped at 8 MiB while being received.

The compiled writer surface covers only one-resource `ENABLE` or `DISABLE` updates for manual
campaigns, manual non-Reach-and-Frequency ad groups, and manual non-ACO ads.
Every library call and CLI command must declare its closed resource family;
only `MANUAL` passes local validation, before credentials or transport.
Ad-group requests always send `allow_partial_success=false`. There is no
`DELETE`, arbitrary URL, arbitrary body, creation, budget, bid, targeting, or
creative operation. Each CLI mutation requires `--confirm-status` to exactly
match `--status`.

The practical implementation intentionally excludes the speculative durable
plan/journal/quarantine/archive/rollback subsystem described in older design
iterations. A caller that needs crash-recoverable orchestration must provide it
outside this process and account for TikTok's lack of an evidenced conditional
status mutation or idempotency key.

## Build and test

```bash
mise install
mise run lint
mise run test
mise run build
scripts/check-exported-api.sh
swift run tiktok-business-gateway-reader --help
swift run tiktok-business-gateway-writer --help
```

Products:

- `TikTokBusinessGatewayShared`
- `TikTokBusinessGatewayReaderCore`
- `TikTokBusinessGatewayWriterCore`
- `tiktok-business-gateway-reader`
- `tiktok-business-gateway-writer`

## Configuration and credentials

The default config path is
`~/.config/tiktok-business-gateway/profiles.json`. Override it with `--config`
or the non-secret `TIKTOK_BUSINESS_GATEWAY_CONFIG` path variable.

```json
{
  "schemaVersion": 1,
  "profiles": [
    {
      "id": "sandbox-reader",
      "capability": "reader",
      "apiVersion": "v1.3",
      "accessTokenEnvironmentVariable": "TIKTOK_SANDBOX_READER_ACCESS_TOKEN",
      "advertiserIds": ["1234567890123456789"],
      "operations": [
        "advertisers.get",
        "campaigns.list",
        "adgroups.list",
        "ads.list",
        "reports.integrated"
      ]
    },
    {
      "id": "sandbox-writer",
      "capability": "writer",
      "apiVersion": "v1.3",
      "accessTokenEnvironmentVariable": "TIKTOK_SANDBOX_WRITER_ACCESS_TOKEN",
      "advertiserIds": ["1234567890123456789"],
      "operations": [
        "campaigns.status.update",
        "adgroups.status.update",
        "ads.status.update"
      ]
    }
  ]
}
```

The sample values are placeholders, not credentials or known accounts.
Profiles contain environment-variable names only. Access tokens are injected
as the `Access-Token` request header after profile, operation, and advertiser
validation. `advertisers.list` is the sole operation that additionally needs
`appId` and `appSecretEnvironmentVariable`; its app secret is attached only to
that fixed endpoint's query. Never place token or secret values in arguments,
configuration, logs, fixtures, or documentation.

The only documented human test-account identity is
`taco-dev-sandbox@mutvar.com`. It is non-secret metadata and does not imply a
credential, advertiser grant, app permission, or environment-variable name.

## Reader examples

```bash
swift run tiktok-business-gateway-reader auth status --profile sandbox-reader
swift run tiktok-business-gateway-reader advertisers get \
  --profile sandbox-reader --advertiser-id 1234567890123456789
swift run tiktok-business-gateway-reader campaigns list \
  --profile sandbox-reader --advertiser-id 1234567890123456789 \
  --page 1 --page-size 100
```

Report requests are bounded JSON files. Dates cannot be in the future and the
inclusive range is limited to 31 days.

```json
{
  "advertiser_id": "1234567890123456789",
  "data_level": "AUCTION_CAMPAIGN",
  "dimensions": ["campaign_id", "stat_time_day"],
  "metrics": ["spend", "impressions", "clicks"],
  "start_date": "2026-08-15",
  "end_date": "2026-08-15",
  "page": 1,
  "page_size": 100
}
```

```bash
swift run tiktok-business-gateway-reader reports integrated \
  --profile sandbox-reader --request-file report.json
```

Safe reads retry at most twice after the first attempt with bounded exponential
backoff for HTTP 408, 429, 5xx, and pre-response transport failures. Retry mode
is derived from the fixed operation method and cannot be selected by callers.
Ambiguous TikTok application throttle codes are surfaced without retry. All
redirects are rejected. Provider success requires both HTTP 2xx and TikTok
envelope `code == 0`.

## Writer examples

Review the target account, resource, and desired status before running a
mutation. This command can change live delivery state:

```bash
swift run tiktok-business-gateway-writer adgroups status update \
  --profile sandbox-writer \
  --advertiser-id 1234567890123456789 \
  --resource-id 9876543210987654321 \
  --resource-family MANUAL \
  --status DISABLE \
  --confirm-status DISABLE
```

`--resource-family MANUAL` is a required local assertion and does not prove the
provider-side resource family; operators must keep it aligned with the selected
sandbox resource. Writer responses are never retried after an HTTP response or any transport
failure whose dispatch outcome is unknown. Only a transport error explicitly
classified as pre-dispatch may be retried. A successful provider envelope is
not proof that this process caused the later observed status.

## Verification without credentials

```bash
curl --proto '=https' --tlsv1.2 --max-time 15 \
  -o /dev/null -sS -w '%{http_code}\n' \
  https://business-api.tiktok.com/open_api/v1.3/advertiser/info/
```

An authenticated smoke test is optional and must use an existing documented
environment, an allowlisted sandbox advertiser, and non-serving resources.
No smoke mutation should be attempted merely because credentials are present;
the resource and intended status must be independently confirmed first.

## Design and implementation notes

Official endpoint evidence and limitations are retained under
`design-docs/`. The practical implementation plan is
`impl-plans/tiktok-business-gateway.md`. The implementation uses the sibling
`google-marketing-gateway` only for architectural conventions; TikTok endpoint,
authentication, pagination, model, and permission semantics remain TikTok-
specific.

The current TikTok portal, credential, verification, and next-session state is
recorded in `design-docs/session-handover-2026-08-16.md`.

## Packaging note

The Homebrew Formula and Cask builders package both reader and writer products.
Their dry-run plans can be inspected without credentials or publication:

```bash
scripts/build-homebrew-release.sh --dry-run darwin-arm64 darwin-x64
scripts/build-homebrew-cask-release.sh --dry-run darwin-arm64 darwin-x64
scripts/check-reader-artifact-boundary.sh
scripts/check-release-builder-safety.sh
```

The default test suite is offline-safe. Run the unauthenticated official HTTPS
transport check explicitly when network integration verification is intended:

```bash
scripts/check-official-https.sh
```

No release, signing, notarization, upload, or tap mutation was performed for
this implementation. See `packaging/homebrew/README.md` and the repository
release skills before using those workflows.

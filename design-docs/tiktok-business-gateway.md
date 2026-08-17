# TikTok Business Gateway

**Status:** Historical safety annex; practical implementation reconciliation in
`design-docs/tiktok-business-gateway-design.md` takes precedence

**Authoritative as of:** 2026-08-16

**Target:** Swift 6.3, macOS 14+, Swift Package Manager

This entire file is historical rationale. It defines no current acceptance,
enablement, CLI, lifecycle, persistence, or release requirement and cannot
broaden or disable the current manifest catalog.

The durable writer-state sections below are not implemented. They are retained
as historical design research, not as current CLI or acceptance requirements.
The current writer performs only direct, explicitly confirmed, one-resource
status calls and persists no plan or writer state.

## 1. Outcome

Build a local CLI gateway for bounded TikTok Marketing API ad-account reads
and deliberately narrow ad-delivery status changes. Reader and writer are
different Swift modules and executables. The reader binary cannot link writer
routes. The writer exposes only plan/apply/reconcile flows for `ENABLE` and
`DISABLE` on manual campaigns, ad groups, and ads.

No code is implemented in this workflow. An implementation plan is also out of
scope and remains reserved for `impl-plans/tiktok-business-gateway.md`.

## 2. Goals, non-goals, and acceptance

### Goals

- Preserve TikTok v1.3 identifiers, pagination, error envelopes, permissions,
  reporting values, and version semantics rather than normalizing them to a
  Google-shaped API.
- Enforce reader/writer authorization at package, executable, profile,
  operation-catalog, and request-builder boundaries.
- Offer useful account, campaign, ad-group, ad, and synchronous report reads.
- Make status changes reviewable, single-resource, single-dispatch,
  crash-recoverable, and reconciled after every possible dispatch.
- Keep credentials and private payloads out of arguments, configuration,
  output, diagnostics, plans, fixtures, and documentation.
- Bound request size, response size, pagination, memory, concurrency, time,
  retries, and durable local state.

### Non-goals

- A generic HTTP proxy, arbitrary method/path/header/body runner, hosted
  service, daemon, web UI, or credential broker.
- Campaign, ad-group, or ad creation; `DELETE`; budget, bid, targeting,
  creative, identity, audience, event, catalog, billing, Business Center,
  permission, or account mutation.
- Smart+, Upgraded Smart+, GMV Max, Reach & Frequency, ACO, Spark Ads,
  Organic API, asynchronous reports, uploads, or webhooks in slice one.
- Authorization callback handling, authorization-code exchange, token
  revocation, or token persistence.
- Inferring that a human Business Center role proves developer-app scope or
  advertiser authorization.

### Design acceptance criteria

1. Every callable operation has a fixed official origin, version, method,
   path, permission, typed schema, limits, and sanitized fixture reviewed by
   two different reviewers.
2. ReaderCore has no dependency on WriterCore and the reader executable has no
   writer command registration, concrete writer request builder, or mutation
   transport.
3. All non-secret local validation and authorization complete before secret
   resolution; fixed request construction completes before credentials are
   attached; provider authorization is then established by the authenticated
   safety read.
4. Every writer apply has a current plan digest, an atomic durable claim, a
   writer-wide lock, a final drift read, one non-replayable dispatch per
   resource, durable dispatch evidence, and mandatory readback.
5. Success requires both acceptable HTTP status and TikTok application
   `code == 0`.
6. No secret value is persisted or emitted to local output, logs, diagnostics,
   request descriptions, crash context, or test failures. Credentials appear
   only in the exact official request position after redaction is armed.
7. Deep, broad, adversarial, and source/security review leaves zero unresolved
   high- or medium-severity findings.

Design acceptance does not enable live operations. Production readiness also
requires the endpoint evidence, catalog, contract tests, approved-app scope,
and authenticated sandbox gates in Section 16.

## 3. Current repository and reference behavior

The repository currently contains a minimal `AppCore`, one `AppCLI`, and basic
help/version tests. It has no API transport, authentication, profile, domain,
or persistence implementation. All Swift files are below 1000 lines.

The sibling `google-marketing-gateway` provides useful local conventions:
separate capability binaries, fixed operation catalogs, profile allowlists,
validation before credential resolution, dependency-injected transport and
time, structured JSON, stable exits, and plan/apply mutation flows. TikTok
endpoint, permission, authentication, pagination, reporting, and error facts
must come only from TikTok's official documentation.

## 4. Current official evidence

All sources below are first-party and were retrieved on 2026-08-15. The public
documentation pages and TikTok's public documentation-content endpoint both
reported v1.3. The API reference, authorized-ad-account, campaign-status, and
rate-limit pages were publicly reachable again on 2026-08-16. No credential or
signed-in session was used.

| Official source | Design evidence |
|---|---|
| [About API for Business](https://ads.tiktok.com/help/article/marketing-api?lang=en&redirected=1) | Marketing API queries and manages Ads Manager data and supports customized reporting. |
| [API reference](https://business-api.tiktok.com/portal/docs/api-reference/v1.3) | Non-MCP base URL is `https://business-api.tiktok.com/open_api`; current version is v1.3; endpoint names and permission labels below. |
| [Marketing API authorization](https://business-api.tiktok.com/portal/docs/marketing-api-authorization/v1.3) | Advertiser authorization is required; the authorization code lasts one hour and is single-use. |
| [Long-term access token](https://business-api.tiktok.com/portal/docs/obtain-a-long-term-access-token/v1.3) | Long-term Marketing API tokens do not expire, can be revoked, and result from app ID/secret plus authorization code. |
| [Return codes](https://business-api.tiktok.com/portal/docs/return-codes-appendix/v1.3) | Application code controls success even with HTTP 200; documented throttle codes include 40016, 40100, and 40133. |
| [HTTP status codes](https://business-api.tiktok.com/portal/docs/http-status-codes/v1.3) | HTTP 200 still requires application-code inspection; 4xx and 5xx have distinct handling. |
| [Rate limits](https://business-api.tiktok.com/portal/docs/rate-limits/v1.3) | Basic app defaults are 10 QPS, 600 QPM, and 864,000 QPD; limits also exist per endpoint; QPM throttling may require five minutes and QPD until 00:00 UTC. |
| [Business Center permissions](https://ads.tiktok.com/help/article/about-assets-and-asset-level-permissions?redirected=2) | Analyst is read-only for ads/reports; Operator/Admin can edit ads, but local policy remains narrower. |

### Proposed endpoint catalog

Every entry starts `proposed-disabled`. It may become callable only after the
same-revision two-reviewer evidence and tests in Section 16. Exact identifiers
are strings.

| Operation | Official endpoint and permission | Capability | Slice-one constraints |
|---|---|---|---|
| `advertisers.list` | [`GET /oauth2/advertiser/get/`](https://business-api.tiktok.com/portal/docs/get-authorized-ad-accounts/v1.3); Ad Account Information read | Reader | Requires access token, app ID, and app secret; secret is resolved only for this operation. |
| `advertisers.get` | [`GET /advertiser/info/`](https://business-api.tiktok.com/portal/docs/get-ad-account-details/v1.3); Ad Account Information read | Reader | Exactly one locally allowlisted advertiser ID and allowlisted fields. |
| `campaigns.list` | [`GET /campaign/get/`](https://business-api.tiktok.com/portal/docs/get-campaigns/v1.3); Campaign read | Reader | Manual campaigns only; ID filter max 100; page size 1...1000. |
| `adgroups.list` | [`GET /adgroup/get/`](https://business-api.tiktok.com/portal/docs/get-ad-groups/v1.3); Ad Group read | Reader | Manual, non-R&F groups only; ID filters max 100; page size normally 1...1000. |
| `ads.list` | [`GET /ad/get/`](https://business-api.tiktok.com/portal/docs/get-ads/v1.3); Ad read | Reader | Manual `ad_ids` only; ID filters max 100; page size 1...1000. |
| `reports.integrated` | [`GET /report/integrated/get/`](https://business-api.tiktok.com/portal/docs/run-a-synchronous-report/v1.3); Consolidated Report | Reader | BASIC synchronous report, one advertiser, allowlisted dimensions/metrics, page size 1...1000; throttle header is surfaced safely. |
| `campaigns.status.update` | [`POST /campaign/status/update/`](https://business-api.tiktok.com/portal/docs/update-the-operation-statuses-of-campaigns/v1.3); Campaign create/update | Writer | One manual campaign; `ENABLE` or `DISABLE`; omit `postback_window_mode`. |
| `adgroups.status.update` | [`POST /adgroup/status/update/`](https://business-api.tiktok.com/portal/docs/update-the-statuses-of-ad-groups/v1.3); Ad Group create/update | Writer | One manual, non-R&F group; `ENABLE` or `DISABLE`; force `allow_partial_success=false`. |
| `ads.status.update` | [`POST /ad/status/update/`](https://business-api.tiktok.com/portal/docs/update-the-statuses-of-ads/v1.3); Ad create/update | Writer | One manual `ad_id`; `ENABLE` or `DISABLE`; exclude `aco_ad_ids`. |

TikTok permits 1...20 IDs in each status request and documents `DELETE`, but
the gateway intentionally sends one ID and denies `DELETE`. TikTok documents
partial success for ad groups only when `allow_partial_success=true`; the
gateway always sends false. The campaign and ad pages do not establish
conditional mutation, idempotency, or rejection atomicity, so none is assumed.

## 5. Architecture and authorization boundaries

### SwiftPM targets and products

| Target/product | Dependencies | Authority |
|---|---|---|
| `TikTokBusinessGatewayShared` | Foundation | Value types, config, errors, redaction, catalog metadata, clocks/sleepers/randomness protocols; no concrete network client. |
| `TikTokBusinessGatewayReaderCore` | Shared | Typed reader client, reader catalog, fixed read request builders, bounded read transport. |
| `TikTokBusinessGatewayWriterCore` | Shared + ReaderCore | Typed writer client, writer catalog, plans, journals, one-shot writer transport; ReaderCore only for fixed safety reads. |
| `tiktok-business-gateway-reader` | Shared + ReaderCore | Reader commands only. |
| `tiktok-business-gateway-writer` | Shared + ReaderCore + WriterCore | Plan/apply/reconcile/rollback and state-maintenance commands only. |
| `tiktok-business-gateway` | None | Removed in slice one; no compatibility executable, alias, wrapper, or command grammar is shipped. |

No planned non-generated Swift file may exceed 1000 lines. Split types by
configuration, transport, catalog, resource model, pagination, CLI, plan,
journal, and recovery responsibility. Tests mirror target boundaries.

### Invariants

- Production origin is exactly `https://business-api.tiktok.com`; every path
  starts `/open_api/v1.3/` and comes from an immutable compiled catalog.
- Callers cannot supply an origin, URL, method, path, API version, header,
  permission, arbitrary body, or unknown JSON field.
- ReaderCore cannot import WriterCore. Package-graph and symbol/CLI tests prove
  the reader artifact contains no writer route.
- A profile has exactly one capability, at least one advertiser ID, and an
  explicit operation allowlist. Reader rejects writer profiles and writer
  rejects reader profiles.
- Every trust-bearing JSON document rejects duplicate object keys at every
  nesting level before typed decoding. Profile IDs match
  `[a-z][a-z0-9-]{0,63}` and are unique. Advertiser IDs are canonical nonzero
  decimal strings of 1...64 digits; operation IDs are compiled ASCII enum
  values. Duplicate profile IDs, advertiser IDs, operation IDs, resource IDs,
  or identities that conflict after the specified normalization reject the
  entire document before profile selection or secret resolution.
- Advertiser and resource IDs are nonempty decimal strings and never pass
  through floating point.
- Every requested advertiser is locally allowlisted before any credential is
  resolved. Authorized-advertiser results are intersected with the allowlist.
- A writer profile permits only the three status operations plus their exact
  internal safety-read dependencies; it does not expose arbitrary read CLI
  commands.
- Redirects are rejected before following. Credentials attach only after fixed
  origin/path validation.
- Provider `request_id` is diagnostic correlation, not idempotency proof.

## 6. Authentication, configuration, and secrets

The operator obtains authorization and a long-term Marketing API token through
TikTok's official flow outside the gateway. Slice one never accepts an
authorization code, app secret, or access token in a command argument and never
stores or refreshes a token.

Default config is
`~/.config/tiktok-business-gateway/profiles.json`, overrideable by `--config`
or `TIKTOK_BUSINESS_GATEWAY_CONFIG`; the environment value is a path only.
Every `~` path in this annex means the effective-user account-record home from
`getpwuid_r(geteuid())`, never the `HOME` environment variable.

```json
{
  "schemaVersion": 1,
  "profiles": [{
    "id": "sandbox-reader",
    "capability": "reader",
    "apiVersion": "v1.3",
    "accessTokenEnvironmentVariable": "TIKTOK_SANDBOX_READER_ACCESS_TOKEN",
    "appId": "example-app-id",
    "appSecretEnvironmentVariable": "TIKTOK_SANDBOX_APP_SECRET",
    "deploymentId": "sandbox-mac",
    "networkBoundaryId": "sandbox-direct-egress-v1",
    "advertiserIds": ["1234567890123456789"],
    "operations": ["advertisers.list", "advertisers.get", "campaigns.list"]
  }]
}
```

The example has no real credential or account. `appId`, the app-secret
reference, `deploymentId`, and `networkBoundaryId` are required exactly when
`advertisers.list` is allowlisted and forbidden otherwise. The two IDs match
`[a-z][a-z0-9-]{0,63}` and are non-secret deployment labels.
The app secret and access token are resolved after all non-secret validation.
Environment-variable names match `[A-Z][A-Z0-9_]{0,127}` and cannot use known
ambient credential names.

Configuration uses the same duplicate-key-rejecting bounded parser as plans.
No trimming or case folding is implicit: schema strings must already be NFC,
profile IDs must match the lowercase grammar above, advertiser IDs must already
be canonical decimal, and operations must exactly match catalog IDs. Arrays are
sets for authorization purposes and therefore reject duplicates rather than
silently deduplicating them. A file containing any conflicting identity is
invalid as a whole; array order never selects a winner.

For each profile, compute `profileAuthorizationFingerprint` as lowercase
SHA-256 over the RFC 8785 canonical encoding of schema version, profile ID,
capability, API version, optional non-secret app ID, the access-token and
app-secret environment-variable names, optional deployment/network-boundary
IDs, sorted advertiser IDs, sorted operation IDs, and catalog revision,
prefixed by
`tiktok-business-gateway.profile-authorization.v1` plus a zero byte. Plans bind
this fingerprint; optional fields are encoded as explicit JSON null when absent.
Secret values are deliberately excluded: rotating a token in
the same named reference is permitted and must still pass authenticated reads;
changing any reference name or non-secret authorization field makes every
unclaimed plan stale. Post-dispatch recovery may use a different current
profile only under the recovery-profile rules in Section 8.

Config and every writer request/state artifact are opened once with no-follow
semantics, bounded, verified from the open descriptor as regular and owned by
the effective user, and rejected if group/other writable. Writer state is
`0700`; artifacts are exclusive-created `0600`, file-fsynced, atomically
renamed within one directory, then directory-fsynced.

`advertisers.list` is the exceptional official GET that requires an app secret
in the query. It uses a dedicated one-operation transport and a newly created
ephemeral URL session; shared, default, background, discretionary, reusable, or
persistent sessions are forbidden. The configuration has no URL cache, uses a
reload-ignoring-local-and-remote-cache policy, rejects all redirects, disables
cookies and cookie acceptance, has no credential store, disables connectivity
waiting and request/body tracing, supplies an empty proxy override, rejects
HTTP/proxy/client-certificate authentication challenges, and retains no task
metrics or gateway request history. The session is invalidated immediately
after its single task and cannot enter a pool.

This operation is supported only when all inspectable deployment preconditions
pass before secret resolution: the compiled Foundation/CFNetwork runtime is a
release-tested version; the actual ephemeral session configuration matches the
cataloged no-cache/no-cookie/no-credential/no-redirect policy; the process has
no HTTP, HTTPS, ALL, or SOCKS proxy environment setting; system proxy settings
report no HTTP/HTTPS/SOCKS proxy, PAC URL, or automatic proxy discovery; no
custom proxy dictionary is present; and required cache, cookie, credential,
challenge, redirect, and diagnostic controls are available. Any detected proxy,
PAC, auto-discovery, unsupported runtime, missing inspection API, or ambiguous
setting keeps `advertisers.list` disabled before the app secret is read.

External network infrastructure is an explicit deployment-owner trust
boundary. The gateway cannot detect every VPN, network extension, endpoint
security product, TLS-inspection appliance, upstream proxy, packet recorder, or
provider-side log. Production enablement therefore also requires a dated
non-secret deployment attestation that the path to TikTok has no component
configured to persist full URLs or query strings and that applicable diagnostic
collection is disabled. This attestation is evidence of an operating
precondition, not proof of universal non-persistence. If the environment cannot
make that assertion, the operation remains disabled; the other eight operations
are unaffected.

The attestation is a versioned, non-secret, owner-controlled JSON document at
the fixed path
`~/.config/tiktok-business-gateway/attestations/<profile-id>.json`; no CLI,
environment variable, profile field, or symlink can override that location.
The directory is effective-user-owned mode `0700`. The file is opened once with
no-follow semantics, is at most 16 KiB, is a regular file owned by the effective
user, is not group/other writable, and is parsed from that descriptor with
duplicate-key rejection and no unknown fields. Schema v1 is:

```json
{
  "schemaVersion": 1,
  "kind": "advertisers-list-direct-transport",
  "profileId": "sandbox-reader",
  "deploymentId": "sandbox-mac",
  "networkBoundaryId": "sandbox-direct-egress-v1",
  "profileAuthorizationFingerprint": "<sha256>",
  "appId": "example-app-id",
  "apiVersion": "v1.3",
  "catalogRevision": "v1.3-design-4",
  "origin": "https://business-api.tiktok.com",
  "executableSHA256": "<sha256>",
  "osBuild": "<exact-tested-build>",
  "foundationRuntime": "<exact-tested-runtime>",
  "bootSessionId": "<current-boot-session-id>",
  "issuedContinuousNanoseconds": 123456789,
  "validForSeconds": 86400,
  "attestorId": "change-record-identifier",
  "assertions": {
    "directTikTokEgress": true,
    "noTLSInspection": true,
    "noFullURLOrQueryLogging": true,
    "diagnosticCollectionDisabled": true
  },
  "issuedAt": "2026-08-16T00:00:00Z",
  "expiresAt": "2026-08-17T00:00:00Z",
  "digest": "<sha256>"
}
```

`attestorId` is a restricted ASCII identifier matching
`[A-Za-z0-9][A-Za-z0-9._:-]{0,127}`, not free-form text or an email. The digest
is lowercase SHA-256 over RFC 8785 canonical JSON excluding `digest`, prefixed
by `tiktok-business-gateway.advertisers-list-attestation.v1` and a zero byte.
`issuedAt` may be at most five minutes in the future, `expiresAt` must be later
than `issuedAt`, `validForSeconds` is a positive integer no greater than 86,400,
and `expiresAt - issuedAt` must equal `validForSeconds`. `bootSessionId` is the
current OS boot-session identifier and `issuedContinuousNanoseconds` is the
nonnegative system-wide continuous-clock value captured at issuance.

Attestation freshness is fail-closed and does not rely on wall time alone. The
validator requires the current boot-session identifier to equal the document,
the current continuous clock to be no earlier than issuance, and continuous
elapsed time to be no greater than `validForSeconds`. Reboot always invalidates
the attestation and requires reissuance. The owner-controlled attestation
directory also contains a fixed no-follow `CLOCK` anchor recording the greatest
successfully validated wall time for this boot. Before secret resolution the
gateway requires current wall time to be at least that high-water and at least
`issuedAt - 300 seconds`, then atomically advances and fsyncs `CLOCK`. Missing,
unsafe, corrupt, different-boot, regressed-continuous, or regressed-wall clock
state invalidates the attestation; an existing attestation never permits CLOCK
reinitialization. These rules prevent wall-clock rollback or reboot from
reviving expired evidence.

`CLOCK` is a mode-`0600`, effective-user-owned, regular no-follow JSON file with
the closed fields `schemaVersion: 1`, `kind:
"advertisers-list-attestation-clock"`, `bootSessionId`, `wallHighWater`,
`continuousHighWaterNanoseconds`, and `digest`. Its RFC 8785 digest excludes
`digest` and uses domain
`tiktok-business-gateway.advertisers-list-attestation-clock.v1` plus a zero
byte. The deployment attestation issuer must atomically create and fsync a new
same-boot CLOCK before publishing the attestation; the gateway never creates or
lowers it from an attestation. Each successful pre-secret validation atomically
advances both high-waters before reading the app secret. A reboot requires the
issuer to replace CLOCK and the attestation as one stopped-gateway deployment
operation; mixed boot IDs fail closed.

Before every `advertisers.list` secret lookup, the gateway validates file
safety, schema, digest, boot/continuous/wall time, all four literal-true assertions, and exact
equality with the selected profile ID, deployment/network-boundary IDs,
authorization fingerprint, app ID, API/catalog revision, fixed origin, running
executable digest, current OS build, and current Foundation runtime. It then
runs the inspectable proxy/session preflight above. No validation result is
cached across invocations. Any executable/runtime/OS/catalog/profile/app-ID/
deployment/network-boundary change, expiry, clock-invalid time, assertion
change, digest mismatch, unsafe file, detected proxy/PAC/auto-discovery, or
missing inspection capability invalidates the attestation before token or app-
secret resolution and returns exit 2, error kind
`deploymentAttestationInvalid`, action `correctInput`, and only a closed safe
reason enum.

The deployment owner must change `networkBoundaryId` and issue a new
attestation before any VPN, egress, TLS inspection, diagnostic, proxy, or
request-logging change. The gateway cannot verify that operating procedure;
that residual is the explicit external-infrastructure trust boundary. Old
attestations never authorize a different profile, binary, runtime, catalog,
machine deployment, or network boundary.

Its adapter constructs the URL only after redaction is armed and never renders
an absolute URL or query in logs/errors. Tests inject recognizable fake secrets
and inspect raw, encoded, and decoded variants across stdout, stderr, thrown
errors, URL descriptions, debug/task-metrics callbacks, proxy and challenge
callbacks, crash diagnostics, shared and operation-local URL caches, cookie and
credential stores, application container files, and post-invalidation state.
The bounded test snapshots gateway-accessible local stores before and after the
request and requires no new secret-bearing bytes or entries there. It also
table-tests every inspectable precondition and verifies fail-closed behavior.
These tests establish only the supported process/runtime contract; they do not
claim visibility into external infrastructure. If local controls, runtime
version evidence, or the deployment attestation are absent, the operation
remains disabled; other readers do not require the app secret.

The only non-secret test identity is `taco-dev-sandbox@mutvar.com`. It is
manual verification metadata, never a credential key or evidence of access.

## 7. Reader model and user flows

### Public model

```text
TikTokEnvelope<Data> = code:Int, message:String, requestId:String?, data:Data?
TikTokPageInfo = page:Int, pageSize:Int, totalNumber:Int?, totalPage:Int?
GatewayPage<Item> = items, pageInfo, endReached, pagesFetched,
                    retainedItems, encodedBytes, duplicateCount,
                    snapshotConsistency:notGuaranteed,
                    partialReason?, requiredAction?, nextPageHint?, resumable:false
```

Advertiser, campaign, ad-group, and ad models preserve IDs as strings and
provider status/time strings. Only cataloged fields are requested. Reports keep
dimensions and metrics as provider strings; money is not silently converted to
binary floating point. Unknown additive response fields may be ignored by the
runtime decoder but must trigger schema-drift visibility in fixture tests.

### Pagination

- One page is default. `--page` and `--page-size` are accepted only for an
  endpoint that catalogs them. `--all-pages` requires `--max-pages 1...100`
  and cannot combine with `--page`.
- Traversal is sequential per advertiser. A local default page size of 100 is
  below the current official 1000 maximum; ad-group variants whose official
  maximum is 100 are cataloged separately.
- Each catalog entry has positive limits for response bytes, response items,
  JSON depth/string/container size, decoded page bytes, parser scratch,
  encoded page bytes, traversal items/bytes, dedup index, final envelope,
  output buffer, and peak working set.
- Before another page, reserve the maximum next response and stop at the prior
  page boundary if any cumulative or simultaneous-memory bound would cross.
- Parse incrementally. Canonical-encode each validated item once and stream a
  bounded prefix, retained segments, separators, and suffix; do not allocate a
  second complete output document.
- Validate positive/nonregressing page metadata, requested/returned page,
  totals, forward progress, and end conditions. An empty page is a complete
  success with exit 0 and `endReached=true` when cataloged metadata proves
  `totalNumber == 0`, or when an explicitly requested one-page query is beyond
  a nonnegative `totalPage`/`totalNumber` result boundary. During traversal, an
  empty next page is terminal only when consistent metadata proves the prior
  page exhausted the result set or the endpoint's reviewed catalog explicitly
  defines empty-as-end. Otherwise an empty/nonadvancing page is
  `metadataInvalid`; inconsistent totals, conflicting duplicates, timeout,
  cancellation, or a bound produce a complete partial-result envelope and exit
  7 after at least one retained page, or the corresponding first-page error.
- Before any retained page, invalid/empty metadata or conflicting duplicates
  are malformed protocol with exit 6/`manualInspection`; a known local bound is
  exit 2/`correctInput`; and timeout or cancellation is exit 5/`retryLater`.
- Before the first retained page, authentication failure exits 3, permanent
  provider rejection exits 4, throttle or exhausted retryable provider failure
  exits 5, and proven pre-response transport, malformed HTTP, or malformed
  envelope exits 6; stdout is empty and one sanitized error is written to
  stderr. After at least one page is retained, any later-page authentication,
  permission, throttle, permanent rejection, timeout, cancellation, exhausted
  retry, transport, or protocol failure emits exactly one valid partial envelope
  on stdout and exits 7. The envelope retains only fully validated earlier
  pages, never any item from the failed page, includes a closed
  `partialReason` (`limitReached`, `cancelled`, `timeout`, `authentication`,
  `permission`, `throttled`, `throttleWarning`, `permanentProviderRejection`,
  `transientProviderFailure`, `transportFailure`, `malformedResponse`,
  `metadataInvalid`, or `duplicateConflict`), the next requested page as a
  non-resumable diagnostic hint,
  and exactly one action: `reauthorize`, `correctInput`, `retryLater`, or
  `manualInspection`. A sanitized stderr diagnostic may identify the category
  and request ID but cannot repeat items or provider text.
- A later-page throttle records only validated `Retry-After`/throttle metadata
  allowed by the catalog and uses `retryLater`. Malformed envelopes use
  `manualInspection`; authentication/permission uses `reauthorize`; permanent rejection uses
  `correctInput`; transient, timeout, cancellation, and exhausted-retry cases
  use `retryLater`; a bound uses `correctInput`; metadata or duplicate conflict
  uses `manualInspection`. Failure while writing the final partial envelope is exit 6,
  emits no replacement JSON, and never claims that retained data was delivered.
- Resource collections deduplicate identical records by stable ID; conflicting
  duplicates stop. Reports preserve repeated rows unless an official composite
  key is cataloged.
- Pagination is not a snapshot and cannot resume across invocations. A
  `nextPageHint` is diagnostic only.

### Reports

`reports integrated --request-file` accepts versioned bounded JSON for exactly
one allowlisted advertiser, `report_type=BASIC`, allowed data levels,
dimensions, metrics, filters, dates, order, page, and page size. Unknown fields,
unsupported combinations, future/inverted dates, and spans over 31 days fail
before secret resolution. `query_mode=CHUNK`, multi-advertiser reports,
total-metrics aggregation, and Smart+/GMV Max fields are excluded. A valid
`X-Tt-Ads-Throttle` warning on any otherwise successful report page retains
that fully validated page, stops traversal, emits a partial envelope with
`partialReason=throttleWarning`, `requiredAction=retryLater`, sanitized
catalog-allowlisted throttle metadata, and exit 7. This applies on the first,
intermediate, or nominally terminal page and prevents a completeness claim; an
empty first page with the warning is still partial, not a valid empty success.
A missing header follows ordinary completion rules. An oversized or malformed
present header is a protocol failure: first page exits 6 with empty stdout;
after retained pages it returns `malformedResponse`/`manualInspection` partial
output. Raw header values are never emitted.

## 8. Writer plan, state, and transitions

### Request and plan

A request file contains one operation, one advertiser, 1...5 unique resource
IDs, and desired status `ENABLE` or `DISABLE`. Request files are at most 64 KiB;
generated plans are at most 256 KiB. Planning performs exact safety reads and
emits one child plan per resource. Each child is classified from that read as
`actionable` when current differs from desired or `noOp` when it already equals
desired. A request that would mix the classifications is rejected as
`mixedNoOpAndActionable` with exit 2 and no plan; the operator must submit the
actionable and no-op sets separately. Thus every plan is uniformly actionable
or uniformly no-op. The canonical plan binds:

- schema, state epoch, profile ID, profile-authorization fingerprint,
  API/catalog revision, operation, advertiser;
- resource ID/type, child classification, and current/desired status;
- observation digest, wall-clock creation/expiry, boot-session identifier,
  continuous-clock issuance tick, issuance generation, and generated plan ID;
- child ordering, the immutable recovery-read contract described below, and
  complete-plan SHA-256 digest.

Plan ID is display metadata. Plan schema v1 rejects duplicate JSON object keys
at every nesting level before typed decoding. IDs, status values, timestamps,
digests, and enums are strings; schema/count fields are integers; floating-point
numbers are forbidden. Strings must be valid UTF-8 in NFC form. Children are
sorted by ASCII byte tuples containing, in order, `operationId`, `advertiserId`,
`resourceType`, and `resourceId` before hashing. Timestamps use fixed UTC RFC
3339 seconds.

The digest input is the UTF-8 bytes of RFC 8785 JSON Canonicalization Scheme
output for every plan field except `digest`, prefixed with the ASCII domain
separator `tiktok-business-gateway.plan.v1` and a zero byte. SHA-256 is rendered
as lowercase hexadecimal. A decoder re-canonicalizes and compares before use;
cross-process fixtures must produce identical bytes/digests and reject duplicate
keys, non-NFC strings, floats, alternate timestamps, reordered children, and
noncanonical encodings.

The complete digest is the single-use replay identity. Plan creation runs under
the state lock and commits a `planIssued` generation containing the digest,
current wall time, durable wall-clock high-water, OS boot-session identifier,
system-wide continuous-clock tick, and expiry before publishing the plan file.
Plans expire after 10 minutes and bind to the issuing boot session, issuance
generation, current writer-state epoch, and exact non-secret profile
authorization. Environment secret-value rotation behind the same reference does
not invalidate a plan;
reference-name or authorization changes do. Plans and receipts contain no
free-form reason, token, app secret, header, body, account name, or email.

Wall-clock high-water is monotonic state and never decreases. Apply and
rollback-execute reject before claim with exit 8/`correctClock` if the current
wall clock is earlier than the durable high-water, the continuous tick is less
than its issuance tick. They return exit 8/`newPlan` if the boot-session
identifier changed, either wall time is after expiry, or same-boot continuous
elapsed time exceeds 600 seconds. Reboot therefore invalidates every unclaimed
plan/manifest, and a backward clock cannot revive one. `state clock-status` may
inspect the condition but no operator override lowers high-water; the system
clock must be corrected to at least the durable value. Injected wall,
continuous, and boot-session providers make cross-process, reboot, forward-jump,
and backward-jump behavior deterministic in tests.

### Durable state machine

```text
plan: unclaimed -> claimed -> terminal | ambiguityPending | blocked

actionable child:
  untouched -> dispatching -> outcomeRecorded -> observed -> reconciled
  observed/reconciled ambiguity -> ambiguityPending -> ambiguityClosed

no-op child:
  untouched -> noOpObserved

rollback child:
  untouched -> dispatching -> outcomeRecorded -> observed -> reconciled
  accepted/allDesired -> operatorAcknowledgedTerminal
  rejection/allPrior first observation -> reconciled
  persistent rejection/prior or any other complete ambiguity
    -> rollbackAmbiguityPending -> operatorAcknowledgedDenied

Any post-claim missing/corrupt/nondurable evidence
  -> storageIntegrityUnknown  blocks every new writer dispatch

ambiguityClosed
  -> terminal non-dispatching record + permanent affected-resource denylist

mutation authority:
  enabled -> permanentlyBlockedQuarantine -> permanentlyBlockedQuarantined
  permanentlyBlockedQuarantined -> permanentlyBlockedUnknownPriorState
  permanentlyBlockedUnknownPriorState -> permanentlyBlockedQuarantined
  no transition returns any blocked state to enabled

legacy migration:
  detectedSingleValid -> intentPublished -> canonicalActivated
  canonicalActivated -> sourceRetiredExceptLock -> sourceLockRetired
  sourceLockRetired -> migrationComplete
  detectedSplitOrInvalid -> quarantineOnly

post-reset maintenance:
  sealMatched + permanentlyBlockedUnknownPriorState -> closed maintenance set
  candidateDrift -> inspect -> re-quarantine -> re-reset -> sealMatched
```

Writer state has a stable `CURRENT` epoch root, monotonic generation, root
digest, one crash-releasing state transaction lock, claims keyed by full plan
digest, hash-chained journals, immutable observations, receipts, and rollback
aggregates. Any unresolved `possiblySent`, contradictory provider/observation
pair, mixed/divergent observation, corrupt record, or rollback child blocks all
new dispatch, even for another profile. A fully observed structurally intact
ambiguity can leave this global pending state only through the digest-bound
non-network `ambiguity-close` transition below. That transition permanently
denies future mutation of the affected resources and clears only this claim's
global block. Missing/unreadable observations, corrupt/nondurable evidence, and
active rollback children cannot use it and remain globally blocking.

The canonical production writer-state parent is the effective user's
account-record home directory, resolved with `getpwuid_r(geteuid())` rather
than `HOME`, plus the literal relative path
`Library/Application Support/tiktok-business-gateway/writer-state/v1`.
`canonicalStateParent` means that exact descriptor-resolved directory in every
command, product, version, release, and recovery flow. The sole production
locations are `canonicalStateParent/writer-mutation.lock`,
`canonicalStateParent/CURRENT`, `canonicalStateParent/AUTHORITY`,
`canonicalStateParent/epochs/`, `canonicalStateParent/checkpoints/`,
`canonicalStateParent/backups/`, `canonicalStateParent/quarantine/`, and
`canonicalStateParent/migrations/`; an epoch root is always
`canonicalStateParent/epochs/<epoch-id>` and is never the state parent.
Production has no environment, config, CLI, executable-name, bundle-ID, or
version override. The trusted OS resolver opens the account-record home and
verifies that home is effective-user-owned and non-symlink; every descendant
component from `Library` through the root is opened by descriptor traversal and
must be effective-user-owned, non-symlink, and not group/other writable. The
root is mode `0700`, and files use the modes specified below. Standardized path
bytes and the opened device/inode chain must match this canonical resolution.
Alias, symlink, ownership, mode, or path-identity ambiguity is
`storageIntegrityUnknown` and blocks all dispatch.

Split-state discovery is finite. Catalog `legacyStateRoots.v1` contains exactly
these identifiers, effective-user-account-home-relative paths, and accepted
migration descriptors:

| Root ID | Relative path | Accepted migration descriptor |
|---|---|---|
| `application-support-unversioned` | `Library/Application Support/tiktok-business-gateway/writer-state` | Exact writer-state schema v1 stored directly at the unversioned parent; its descriptor excludes the canonical `v1` child |
| `xdg-data-v1` | `.local/share/tiktok-business-gateway/writer-state/v1` | Exact writer-state schema v1 |
| `xdg-config-v1` | `.config/tiktok-business-gateway/writer-state/v1` | Exact writer-state schema v1 |

The accepted descriptor includes the complete bounded member grammar, canonical
digests, and file modes; a path match without an exact descriptor match is not
migratable. Because the first candidate is the parent directory of
`canonicalStateParent`, its discovery, inspection, quarantine, and migration
member sets always exclude the descriptor-verified canonical `v1` subtree;
they examine only direct legacy markers and members. This exclusion prevents
self-copy/recursion and never excludes any direct unversioned legacy evidence.

Every writer command that reads or changes writer state resolves or
bootstrap-creates only `canonicalStateParent` at mode `0700` and
`canonicalStateParent/writer-mutation.lock` at mode `0600`, acquires that one
lock, and then performs exactly eight no-follow, descriptor-relative `fstatat`
probes at each cataloged root. The closed
`legacyEvidenceMarkers.v2` catalog is `CURRENT`, `AUTHORITY`,
`writer-mutation.lock`, `epochs`, `checkpoints`, `backups`, `quarantine`, and
`migrations`: every canonical child capable of holding authoritative,
recoverable, transitional, or anti-rollback evidence. Discovery is therefore
exactly 24 probes and never recursively enumerates or searches any other
location. Creating the empty canonical parent and lock is not initialization
and cannot create CURRENT, AUTHORITY, an epoch, or migration authority. Any
marker counts as evidence regardless of type, ownership, readability, or the
absence of every other marker; a sole valid, corrupt, or unreadable
`migrations` entry containing or potentially containing INTENT is evidence. A
cataloged root resolving to `canonicalStateParent`'s device/inode is also
evidence. A cataloged directory with none of the eight markers is empty for
discovery purposes. Missing CURRENT/AUTHORITY/epochs/lock never makes another
transition marker ignorable and can never authorize canonical initialization
or dispatch. No other direct child name is permitted to resume, repair, or
establish authority; introducing such an artifact requires a reviewed
`legacyEvidenceMarkers` version bump before any release may read it.

After discovery and while still holding the lock, detected evidence yields
`legacyOrSplitStateDetected`. The base recovery allowlist is exactly `state
inspect`, `state migrate-legacy`, `state quarantine`, and digest-bound `state
reset`; every other command rejects with exit 8/`manualInspection` before
initialization, secret resolution, state mutation, or network unless it passes
the post-reset maintenance gate below. `state inspect` is always reachable: it
reads no secrets, sends no network request, performs bounded no-follow
validation of each discovered candidate against the compiled legacy
descriptors, and binds the ordered candidate root identities, marker inventory,
structural issue classes, stability classification, and candidate digests into
its `inspectionDigest`. `state quarantine` is reachable only with that exact
digest and the stabilization protocol below. `state reset` is reachable only
when its sealed quarantine digest covers every currently discovered candidate.
These exceptions never authorize provider dispatch or silent selection of a
state lineage.

`postResetMaintenanceCommands.v1` is the closed non-network/non-dispatching set
`receipt export`, `state clock-status`, `state checkpoint`, `state backup`,
`state archive-plan`, `state archive`, and `state archive-recovery`. Despite
preserved legacy markers, one of these commands may run only when canonical
AUTHORITY is exactly `permanentlyBlockedUnknownPriorState`, names the reset's
quarantine digest, no migration is pending, and a bounded pre-command scan
proves every candidate device/inode, member, mode, and digest exactly matches
that seal with no additional candidate. Compatible source locks are acquired
after the canonical lock in catalog order. Regardless of whether every existing
candidate is compatibly locked or the seal used explicit quiescence, every
maintenance command performs another complete 24-probe all-root discovery and
bounded candidate scan immediately after its last canonical work/commit and
immediately before any stdout or atomic-output publication. It compares the
entire ordered root set, marker set, device/inodes, members, modes, and digests
to the quarantine seal; locks on existing candidates never substitute for this
final scan because a previously empty root can gain a candidate. Any addition,
removal, replacement, metadata change, or digest drift before work rejects
without change. The same drift at final validation suppresses all output,
preserves any already verified canonical maintenance commit, returns exit
8/`manualInspection`, and blocks later maintenance except
inspect/quarantine/reset. The authority is already permanently non-dispatching,
so no maintenance result can re-enable plan, apply, reconcile, rollback,
restore, initialize, migrate, or epoch rotation.

Post-reset candidate drift has one closed, repeatable executable recovery cycle. `state inspect`
remains available and, when canonical AUTHORITY is
`permanentlyBlockedUnknownPriorState`, emits issue
`postResetCandidateDrift` plus the exact current seal digest, seal sequence,
latest canonical CURRENT/AUTHORITY root, and new inspection digest. The operator
then runs digest-bound `state quarantine --reason
post-reset-candidate-drift`; this reason is valid only for that authority
disposition and issue. It stabilizes and copies the complete changed candidate
set under the ordinary lock/quiescence protocol, creates a replacement seal
whose sequence is predecessor plus one, and binds the predecessor seal digest,
prior seal-chain root, drift inspection digest, and `maintenanceBaseRoot` equal
to the latest verified canonical root. It never deletes or supersedes evidence
from an earlier seal.

Because mutation is already permanently blocked, re-quarantine does not need a
temporary authority downgrade. Before replacement-seal publication and its
CURRENT/AUTHORITY commit, the old reset epoch and old seal remain authoritative
and maintenance remains blocked. A fully copied no-replace staging seal is
non-authoritative but digest-reusable. After publication, one generation commit
atomically changes only the blocked disposition to
`permanentlyBlockedQuarantined`, advances `currentQuarantineSealDigest`,
`quarantineSealSequence`, and the domain-separated `quarantineSealChainRoot`,
and preserves the exact `maintenanceBaseRoot`, every prior seal, claim,
tombstone, block, checkpoint, archive anchor, and committed maintenance change.
A crash before that commit leaves the old blocked authority; exact retry
validates/reuses matching staging. A crash during/after the commit is resolved
from CURRENT/AUTHORITY; identical retry returns the replacement seal receipt.
Conflicting staging or further candidate drift requires a new inspection and
replacement attempt while remaining permanently blocked.

`state reset --quarantine-digest <replacement>` is then reachable from
`permanentlyBlockedQuarantined` under the existing literal acknowledgment. It
accepts only the current replacement seal and creates the next permanently
blocked epoch from the exact latest canonical `maintenanceBaseRoot`, not from
the older reset snapshot. The new epoch carries the entire seal-chain root,
current seal/sequence, all committed maintenance effects and receipts, replay
and denial tombstones, unresolved blocks, high-water, checkpoint/archive
anchors, and candidate inventory. Before the epoch switch the re-quarantined
epoch is authoritative; afterward the new
`permanentlyBlockedUnknownPriorState` epoch is authoritative. Crash recovery
and identical retry use CURRENT/AUTHORITY and are idempotent. An old seal digest
can never reset or replace the current seal. If candidates still match the
replacement seal, the closed maintenance set is reachable again; mutation
authority remains permanently disabled through every cycle.

`state migrate-legacy` has separate fresh-start and INTENT-resume predicates.
Fresh start requires the exact current `--inspection-digest`, one
`--source-root-id` from `legacyStateRoots.v1`, literal
`--ack-legacy-writer-retired`, no canonical CURRENT/AUTHORITY/epoch/quarantine,
no existing INTENT, and exactly one evidence-bearing candidate accepted by its
compiled schema-v1 descriptor. It acquires the existing no-follow compatible
source lock after the canonical lock within the same acquisition deadline and
then recomputes the complete inspection digest while both locks are held; any
change rejects before staging. Multiple candidates, canonical-plus-legacy
evidence, unknown/corrupt schema, unreadable members, or lineage/digest conflict
is quarantine-only. Migration never merges or chooses lineages.

While holding both locks, fresh start byte-verifies the lineage, epoch,
AUTHORITY, CURRENT, claims, replay indexes, journals, observations, tombstones,
blocks, high-water, and modes in a canonical staged copy. It exclusively
publishes and fsyncs the immutable owner-only
`canonicalStateParent/migrations/<migration-digest>/INTENT`. The INTENT binds
the original inspection digest, source root ID and device/inode, source-lock
path/inode, ordered source member paths/digests/modes, target lineage/epoch/root,
retirement order, acknowledgment, and these append-only phases:

| Phase | Canonical predicate | Source-lock and source predicate | Allowed continuation |
|---|---|---|---|
| `intentPublished` | CURRENT/AUTHORITY absent | Bound legacy lock marker exists at its bound inode; every source member remains original | Reacquire bound source lock, validate staged copy, activate exact target |
| `canonicalActivated` | CURRENT/AUTHORITY exactly equal INTENT target and AUTHORITY binds migration digest | Reacquired bound lock; every member is original or at its exact migration-evidence destination | Copy/verify evidence and retire all members except the lock marker |
| `sourceRetiredExceptLock` | Exact bound canonical target | Only the bound lock marker remains; copied lock evidence verifies | While holding its open locked descriptor, unlink the marker last and fsync source parent |
| `sourceLockRetired` | Exact bound canonical target | No catalog marker or unretired member remains | Do not recreate/acquire a legacy lock; verify empty retired inventory and commit receipt |
| `migrationComplete` | Exact bound canonical target and receipt | No catalog marker or unretired member remains | Return the existing receipt idempotently |

Each phase is a separately fsynced no-replace phase receipt; after activation,
CURRENT/AUTHORITY also bind the latest phase. Resume requires
`--resume-migration-digest <migration-digest>` plus the retirement
acknowledgment. It opens only
`canonicalStateParent/migrations/<migration-digest>/INTENT`, verifies the
directory/INTENT digest and phase chain, and derives the immutable original
inspection digest, source root ID, source identity, and target solely from that
INTENT; caller-supplied fresh-start fields are forbidden. It does not reapply
fresh-start's absent-authority predicate. Before `sourceLockRetired`, it
must reacquire the existing INTENT-bound source lock; a missing/replaced marker
is corruption except at the precise crash cut where all other members are
retired and copied lock evidence proves the last unlink, which permits only the
`sourceLockRetired` phase commit. At and after that phase, resume never recreates
the marker and relies on the retirement acknowledgment plus exact zero-marker,
zero-unretired-member validation. Canonical evidence is permitted during resume
only when it exactly matches INTENT; any other root, source reappearance, extra
candidate, phase conflict, or member drift is exit 8/`manualInspection` and
quarantine-only.

The acknowledgment asserts every legacy writer process is stopped and its
package/launcher retired; release verification checks known inventory, while a
manually copied executable remains an operator trust boundary. Migration copies
and verifies source evidence under
`canonicalStateParent/migrations/<migration-digest>/source-evidence`, retires
members in recorded order with the source lock last, and fsyncs both parents at
each batch. Any nonterminal INTENT globally blocks dispatch independently of
remaining markers; only inspect, exact-argument migrate-legacy, or quarantine
may continue. Success requires `migrationComplete`, zero catalog markers,
verified canonical authority, and a durable receipt. Preserved migration
evidence follows quarantine privacy and no-dispatch rules.

The root catalog version, `legacyEvidenceMarkers.v2`, ordered roots/markers,
accepted legacy schema descriptors, and migration transform are compiled constants shared by every writer
product/version; changing any of them requires reviewed fixtures proving
AUTHORITY, claims, replay indexes, tombstones, blocks, and clock high-water are
preserved. Locations outside `canonicalStateParent` and this exact catalog are
not searched and cannot be claimed as detected; copied or renamed state
elsewhere is an explicit residual risk. Tests may inject one isolated
canonical parent and the same finite catalog, but production path/catalog
injection is unavailable.

Every command that reads or changes writer state acquires the same validated
owner-only canonical OS advisory lock: plan, apply, reconcile, rollback plan/execute/
reconcile/acknowledge/resume, initialize, inspect, backup, restore, archive plan/execute, epoch rotation,
quarantine, reset, and migration. The lock is exclusive for slice one and is
held across network work and the entire state transaction. OS process death
releases it; the mere existence or age of the lock file never authorizes stale
lock deletion. The canonical lock is always acquired first. Migration then
acquires its one INTENT-selected compatible source lock. Quarantine and an
eligible post-reset maintenance command acquire every safely compatible source
lock in ascending compiled root-ID order. No other command acquires a second
gateway lock, and incompatible/unreadable source locks are never created,
replaced, deleted, or bypassed as if held. This canonical-then-catalog order is
total. Contention never consumes a plan.

Acquisition is bounded and cancellable. Each command tries the advisory lock
nonblocking until a system-wide continuous-time deadline: 2,000 ms by default;
`--lock-timeout-ms` may only lower it to 0...2,000. It checks cancellation
before every attempt, polls no slower than every 25 ms through an injected
sleeper, and performs no secret resolution, network request, claim, or state
write while waiting. Cancellation or deadline before acquisition returns exit
8/`retryLater` with sanitized `lockBusy` metadata containing only elapsed
milliseconds. Commands requiring source locks share the same one absolute
deadline across canonical and all ordered source acquisitions and release every
acquired lock on pre-work failure. Live and suspended holders are treated identically; the gateway
never reports holder PID/path/command, kills a holder, or deletes a lock file.
A crashed holder is released by the OS, and rapidly restarting contenders get
the same per-invocation bound. Once acquired, cancellation follows the
command's documented transaction and dispatch cut points.

`commitGeneration(event)` is the only durable-state transition primitive. It
writes a complete immutable generation with the prior root digest, event, plan
aggregate, every child state, and the single optional `activeChildIndex`; fsyncs
all files; atomically replaces `CURRENT`; fsyncs the state directory; reopens
and verifies that `CURRENT` names the expected generation/root digest; advances
and verifies the independent `AUTHORITY` anchor described below; and only then
returns. The lock remains held across any number of commits and network
calls. Each listed cut point below is a separate authoritative CURRENT commit,
not a staged journal append or an end-of-command batch.

Generation numbers are monotonic integers. A generation manifest rejects
duplicate keys and is RFC 8785 canonicalized; its lowercase SHA-256 root uses
domain `tiktok-business-gateway.state-generation.v1` plus a zero byte and
includes every content-file digest. `CURRENT` is a bounded canonical pointer
containing schema, epoch, generation number, and root digest. Exclusive files,
manifest, pointer rename, directory fsync, and pointer readback occur in that
order; partial files cannot become authoritative by directory enumeration.

The owner-only `canonicalStateParent/AUTHORITY` file, outside epoch,
generation, checkpoint, backup, quarantine, and migration directories, is
never replaced by restore. It canonically records the
lineage ID, epoch, highest authoritative generation/root, latest checkpoint
root, wall-clock high-water, mutation-authority disposition, and unresolved-
block digest. `permanentlyBlockedQuarantined` and
`permanentlyBlockedUnknownPriorState` additionally require
`currentQuarantineSealDigest`, monotonic `quarantineSealSequence`,
`quarantineSealChainRoot`, and `maintenanceBaseRoot`; the transient initial
`permanentlyBlockedQuarantine` disposition carries its pending inspection
digest with canonical null seal fields, and enabled authority has canonical
null blocked-lifecycle fields. After a verified CURRENT commit, the gateway atomically advances
and fsyncs `AUTHORITY`. A crash with CURRENT one valid descendant ahead of the
anchor is repaired by validating that descendant and advancing `AUTHORITY`
before any command continues. If AUTHORITY is ahead, missing, corrupt, names a
different lineage, or CURRENT is not its exact root or a provable descendant,
the writer fails closed; no restore/reset may infer freshness from filenames,
timestamps, or generation numbers alone.

This anchor protects only the supported in-band lifecycle in which
`canonicalStateParent` and `canonicalStateParent/AUTHORITY` remain current
while a candidate backup is checked.
Restoring the entire parent, APFS snapshot, VM, system image, or copied state
tree can roll back CURRENT and AUTHORITY together and is unsupported and
locally undetectable. Operators must use `state backup` and `state restore` and
must not run the writer after a whole-parent rollback. Known or suspected
out-of-band rollback requires the operator to keep the writer stopped and run
the documented permanently disabling `state reset` workflow, which classifies
`storageIntegrityUnknown`, quarantines the lineage, and permanently blocks
mutation; no local acknowledgment restores authority. Supporting whole-parent restoration would require a separately
reviewed independently monotonic durability domain, such as a remote append-
only ledger or hardware counter. Tests must demonstrate this limitation rather
than claim detection, while documentation and runbooks prohibit the operation.

Only one actionable child may be `dispatching`; its index is the active-child
marker. `untouched` proves that this plan never started that child's mutation.
The marker is set by the authoritative `dispatching` commit, retained through
the outcome commit, and cleared only by that child's observation/finalization
commit before another child can become active.
`dispatching` proves only that the durable marker preceded a possible POST, so
after process death it is always recovered as `possiblySent`. `outcomeRecorded`
stores accepted/rejected/unknown independently from dispatch evidence.
`observed` appends the mandatory readback; `reconciled` appends a later
operator-invoked read round but does not itself prove resolution or authorize
dispatch. `noOpObserved` is legal only in a uniformly no-op plan and proves that
the final safety read already equaled desired without constructing a mutation
request.

Every readback attempt has a durable monotonically increasing
`observationAttemptSequence`. A usable observation additionally increments
`usableObservationSequence`; unreadable/missing attempts never do. When any
provider outcome first produces usable `allPrior`, the same commit sets
`allPriorConfirmation=awaitingLaterUsableConfirmation` and records
`firstAllPriorAttemptSequence`. It cannot enter `ambiguityPending`. Only a later
operator-invoked bounded reconciliation with a strictly greater attempt
sequence and another usable `allPrior` may set
`allPriorConfirmation=confirmed`; intervening missing/unreadable reads retain
the awaiting state, while `allDesired` or `mixedOrDivergent` replaces it with
the corresponding observation classification. Thus an initial unreadable read
followed by the first usable all-prior result still requires one more read
round.

`ambiguityPending` is required for every complete observation whose provider
outcome and observed state cannot establish a safe terminal result: provider
`unknown`; any `mixedOrDivergent`; provider rejection with `allDesired`; or an
`accepted`, rejected, or unknown outcome with `allPriorConfirmation=confirmed`.
An awaiting all-prior confirmation always remains nonterminal with a reconcile
action. These
states are never rollback-eligible. `status ambiguity-close --plan-digest
<sha256> --observation-digest <sha256> --ack-permanent-resource-disable` is a
non-network, non-secret command. Under the state transaction lock it requires
an intact journal, a complete usable latest observation, exact plan and
observation digests, a matrix-classified ambiguity, and no corrupt/nondurable
evidence. It commits `ambiguityClosed`, a terminal receipt, and immutable
resource-denial tombstones carried by checkpoints, backups, archives, restore,
and every later epoch in the lineage. It then clears only the closed claim's
global block; every unrelated block remains. The affected resources can never
be selected by apply or rollback in that lineage. Repeating the exact command
is idempotent; stale digests fail without state change. Recovering mutation
authority for such a resource requires a separately reviewed external
authoritative adjudication design, not reset, rotation, or a new local plan.

On startup under the lock, validate `AUTHORITY`, the latest verified checkpoint,
and the complete chain from that checkpoint to the generation named by
`CURRENT`. Pre-checkpoint generations are not required after committed garbage
collection. A fully fsynced staged generation not named by `CURRENT` was never
authoritative and is quarantined without applying it. The recovery
interpretation is deterministic:

| Authoritative CURRENT state | Crash interpretation and permitted continuation |
|---|---|
| No claim | Plan remains unclaimed; no dispatch was authorized. |
| Claimed; all children untouched | Plan is consumed; reconcile records no dispatch and every child needs a fresh plan. |
| Active child dispatching; no outcome commit | Active child is `possiblySent`; reconcile only. Never call mutation transport. |
| Outcome committed; no observation commit | Preserve outcome; mandatory reconciliation read only. |
| Observation committed; no final receipt commit | Recompute the result from durable axes and commit the receipt; never redispatch. |
| Some children terminal and remainder untouched | Reconcile started children; every untouched child requires a fresh plan. No restart/resume command dispatches it. |
| Named generation/root invalid or required ancestor missing | `storageIntegrityUnknown`; writer-wide dispatch block and `manualInspection`. |

A crash between staging and advancing `CURRENT` leaves the prior row
authoritative. Code cannot start the corresponding external side effect until
the prerequisite `CURRENT` readback succeeds. A crash after POST but before an
outcome commit therefore leaves authoritative `dispatching`, which safely means
`possiblySent`; a crash after a safety read but before its observation commit
leaves the prior state and may repeat only that read.

### Apply algorithm

1. Parse and validate config, request/plan, canonical digest, epoch,
   capability, advertiser, operation, expiry, size/child bounds, and catalog
   revision without secrets. Recompute and compare the bound
   `profileAuthorizationFingerprint`.
2. Acquire the state transaction lock. Validate the complete state index,
   exact unclaimed issuance record, authority disposition, capacity threshold,
   free space, and worst-case journal/recovery reserve before credential
   resolution or network. A missing issuance record returns `newPlan`; blocked
   mutation authority returns `manualInspection`. Lock contention consumes no
   plan and returns `retryLater`.
3. Construct fixed catalog-pinned safety-read requests without credentials.
   Resolve the current writer profile's access-token reference, attach the token
   inside the validated transport, and perform the authenticated reads. Never
   resolve an app secret in WriterCore.
4. Any missing resource, wrong type/account,
   unsupported campaign family, deleted ancestor, R&F/ACO resource, or drift
   consumes no plan and returns `newPlan`. For an actionable plan, any child now
   equal to desired makes the entire plan stale; for a no-op plan, any child no
   longer equal to desired does the same. Final preflight can never convert or
   mix child classifications.
5. Recheck boot session, wall-clock high-water, wall expiry, continuous elapsed
   time, credential-reference/profile fingerprint binding, catalog revision,
   state epoch/generation, and worst-case storage reserve. The token value itself
   may rotate and is never hashed.
   For a uniformly no-op plan, atomically commit one authoritative generation
   containing the permanent claim, final safety-read observation,
   `noOpObserved` for every child, and a terminal receipt with
   `dispatchEvidence=definitelyNotSent`, `providerOutcome=notAvailable`, exit 0,
   and action `none`. This code path neither constructs a mutation request nor
   instantiates mutation transport and returns immediately. For an actionable plan, commit and
   read back an authoritative claim generation with every child `untouched`.
   Once either claim is authoritative, the complete plan is permanently
   single-use.
6. For an actionable plan, start a monotonic 180-second post-claim apply
   deadline. Catalog limits are
   five children, 15 seconds per mutation attempt, 15 seconds for each child's
   mandatory first readback, an exact two-second cancellation-finalization
   start deadline, and
   a 32-second minimum
   remaining budget before starting a child. If that reserve is unavailable,
   do not dispatch that child or any later child; finalize dispatched children
   and require a fresh plan for the remainder.
7. For each child in digest order, call `commitGeneration` to make that child
   `dispatching` and the sole active-child marker authoritative, then read back
   `CURRENT`. Only afterward construct and invoke exactly one POST for exactly
   one resource. Send `allow_partial_success=false` for ad groups and never send
   `DELETE`, `postback_window_mode`, or ACO IDs.
8. Writer transport rejects redirects, authentication/proxy/client-certificate
   challenges, cookies, caches, connectivity waiting, body replay, and client
   retries. A request for a second body stream or any uncertain connection loss
   is `possiblySent`; there is no second mutation task.
9. Immediately call `commitGeneration` to make the provider outcome and
   dispatch evidence authoritative as `outcomeRecorded`. Provider outcome is
   independently `accepted`, `rejectedPermanent`, `rejectedAuth`,
   `rejectedThrottle`, or `unknown`; HTTP/application rejection does not prove
   no mutation. Failure to commit leaves the authoritative child `dispatching`
   and therefore `possiblySent`.
10. Read every dispatched resource once before retrying any readback. Persist
   `desired`, `prior`, `divergent`, `missing`, or `unreadable`, then call
   `commitGeneration` to make the observation authoritative before proceeding
   to another child. A first sweep has no retries and a cataloged absolute
   deadline; later bounded read-only rounds may rotate starting chunks.
   Cancellation after dispatch establishes the absolute continuous-time
   deadline `cancelReceived + 2 seconds`. It prohibits another mutation
   immediately. A not-yet-started safety read may begin only when its clipped
   timeout proves it can finish before that deadline; at the deadline the
   writer cancels any active read and starts no network or new durability
   operation. The read transport is invalidated and every late callback is
   discarded without state mutation. It attempts at most one prebuilt bounded incomplete/cancellation
   generation before the deadline.
11. Call `commitGeneration` for the terminal aggregate and receipt, verify
    `CURRENT`, then emit one `WriterResult`. Output failure never permits
    redispatch; state inspection or reconciliation is the only continuation.

The two seconds is an absolute deadline for starting cancellation-finalization
work, not a false guarantee that the kernel completes a write or `fsync` within
two seconds. If the deadline arrives with no durability call in progress, the
last previously reopened-and-verified `CURRENT` remains authoritative; the
writer emits exit 8 with `reconcile` or `stateInspect` derived from that cached
state and performs no further state write. If a write, `fsync`, rename, or
directory `fsync` entered before the deadline is still blocked in the kernel,
that already-entered uninterruptible durability syscall is not canceled: the
process holds the transaction lock, emits
no result, and waits for the syscall and `CURRENT`/AUTHORITY verification. A
successful verified commit becomes authoritative; failure leaves the prior
verified `CURRENT` authoritative and returns exit 8/`stateInspect`. External
termination is a normal crash cut and startup interprets only verified durable
state. Fixtures inject each blocked durability cut, deadline edge, late
success, failure, and process death; no test or release claim may describe two
seconds as a wall-clock response-time bound.

The first child that is rejected, ambiguous, unreadable, divergent, or cannot
be made durable stops the complete apply. Already dispatched children are
reconciled; undispatched children remain unchanged. There is no forward apply
resume for the consumed plan, including after a crash with an active child.
Remaining intended changes and every durable `untouched` child require a fresh
plan from current provider observations.

The final drift read and POST are separate. No compare-and-set or causal
attribution is claimed. Provider acceptance plus desired observation is called
`acceptedAndDesiredObserved`, not proof that the gateway caused the state.

### Reconcile and rollback

`reconcile --plan-digest` runs under the state transaction lock, only appends
safety reads, never dispatches, and may run after plan expiry. Each claim
journals a non-secret immutable recovery-read contract: API version, catalog
revision and descriptor digest, fixed origin/method/path, advertiser/resource
IDs, requested fields, exact-ID/status projection rules, response limits, and
decoder schema. Credentials and environment-variable names are not journaled.

Before dispatch, any current profile, allowlist, credential reference,
operation enablement, API version, or catalog change makes the plan stale and
requires `newPlan`. After possible dispatch, reconciliation intentionally
survives mutation-operation disablement and plan expiry, but it still requires
a current writer-capable recovery profile that allowlists the advertiser and
the internal safety-read operation. The original profile may be used, or the
operator may pass `--recovery-profile <id>`; the replacement must satisfy the
same account/capability checks. Missing/revoked credentials or provider auth
rejection returns `reauthorizeThenReconcile` without weakening the block.

The binary retains version-pinned recovery decoders/descriptors for every
unresolved journal. A retired/removed descriptor cannot be substituted. A
separately reviewed catalog migration may prove semantic equivalence and append
the new descriptor digest; otherwise `manualInspection` or explicit epoch
quarantine/reset is required. Thus configuration churn has a deterministic
recovery path and never silently reinterprets old evidence.

Automatic rollback is forbidden. `rollback-plan` runs under the state lock and
is strictly non-network: it never constructs a transport, resolves a token, or
performs a provider read. It requires `--selection-file`; there is no implicit all-eligible default. The
bounded schema contains exactly 1...5 canonical resource IDs and rejects
duplicate keys, duplicate IDs, unknown fields, and resources outside the parent
plan before secrets. Selection order is ignored and canonical digest order
governs. Every selected child must be locally authorized and have a terminal
provider-`accepted` receipt with latest observation `allDesired`, a recorded
prior status, no unresolved state, and no permanent resource-denial tombstone.
Rejected, unknown, contradictory, mixed/divergent, `ambiguityPending`, and
`ambiguityClosed` children are never rollback-eligible. One ineligible child
rejects the complete selection without a manifest.
The gateway hashes the ordered `(resourceId, latestObservationDigest)` pairs
with domain `tiktok-business-gateway.rollback-selection.v1` plus a zero byte.
Non-network `rollback-inspect` emits the eligible selected children and this
aggregate observation digest from one locked snapshot. The operator then
supplies it through `--observation-digest <sha256>` plus the separate literal
`--ack-external-origin-risk` flag to `rollback-plan`; any intervening
durable state or observation change invalidates the digest and forces another
inspection. `rollback-plan` reopens the same locked canonical snapshot,
recomputes the selection digest, performs only local capability/profile/
advertiser validation without credential presence checks, and commits the
`rollbackIssued` record before atomically delivering the manifest. Local
validation, digest, state, capacity, cancellation, or output failure performs
no provider read and emits no usable manifest. A manifest
contains schema, state epoch, parent
plan/claim digest, profile ID and authorization fingerprint, API/catalog and
recovery-descriptor revisions, selection observation digest, literal
external-origin acknowledgment,
wall-clock creation/expiry, boot-session identifier, continuous issuance tick,
issuance generation, ordered
children with resource identity/current observation/prior target and the
literal `actionable` classification, and aggregate digest. It is limited to
five children and 256 KiB, expires in 10 minutes, and uses the plan's duplicate-
key, NFC, ordering, integer, RFC 8785, and SHA-256 rules with domain separator
`tiktok-business-gateway.rollback-manifest.v1` plus a zero byte. Slice one has
no no-op or mixed rollback-manifest classification. Before publishing a valid manifest, `rollback-plan` commits its
`rollbackIssued` record using the same boot, continuous-clock, wall-high-water,
capacity, and output-failure rules as plan issuance.

`rollback-execute` requires the full manifest digest, current epoch, unexpired
manifest, valid same-boot/clock-high-water state, unchanged parent/observation
digest, matching authorization fingerprint, and the external-origin
acknowledgment repeated as the literal `--ack-external-origin-risk` flag. No
acknowledgment flag carries or substitutes for an observation digest. Under the
same lock it
performs fixed authenticated safety reads before claim. Any stale observation,
changed resource, changed authorization reference, already-desired/actionable
classification change, missing ancestor, or catalog drift rejects the whole
manifest before claim with `newRollbackPlan`; observing the rollback target
already present is stale external state, not a no-op manifest. An actionable manifest atomically
claims its digest in the shared replay index and then uses the identical
per-child authoritative commits, one-shot transport, 180-second deadline,
32-second child reserve, mandatory readback, stop conditions, exit/action
mapping, and aggregate reduction as apply. Every rollback observation remains
noncausal; no result says the gateway restored provider history.

Cancellation before claim leaves the manifest usable. Cancellation after claim
commits the current evidence: a child whose authoritative state is
`dispatching` becomes `possiblySent`, completed children remain immutable, and
untouched children require a fresh rollback manifest. Process restart and
`rollback-reconcile` only read and commit observations; neither can dispatch.
Rollback reconciliation may run after manifest expiry and accepts
`--recovery-profile` under the same pinned recovery descriptor and current
advertiser/safety-read authorization rules as ordinary reconciliation.

`rollback-reconcile` is phase one of terminal recovery: it commits a bounded
read round and emits the canonical latest aggregate observation digest, but
never terminalizes a rollback aggregate. Phase two is the non-network,
non-dispatching `rollback-acknowledge` command with required manifest digest and
latest aggregate `--observation-digest <sha256>` plus the separate literal
`--ack-external-origin-risk` flag. Under the state lock it requires an exact
digest match to the current aggregate and a
usable latest observation (`allDesired`, `allPrior`, or `mixedOrDivergent`) for
every started child. Missing/unreadable observations cannot be acknowledged.
It commits and verifies an authoritative `operatorAcknowledgedTerminal`
receipt, clears only that rollback aggregate's writer-wide block, and retains
the noncausal/external-origin warning and every replay tombstone. Untouched
children still require a fresh manifest.

Only provider-`accepted` plus `allDesired` is clean terminal rollback state and
may acknowledge without resource denial. Every other first usable complete
observation, including every rollback rejection plus `allPrior`, remains
globally blocked and requires at least one later bounded `rollback-reconcile`
round; no ambiguity acknowledgment is accepted before that round. If any
rejection plus a usable complete observation persists, or for provider
`unknown` with a usable complete observation, accepted plus `allPrior`, or any
`mixedOrDivergent` observation, acknowledgment transitions the child through
`rollbackAmbiguityPending` and atomically installs the same permanent affected-
resource denial used by `ambiguity-close` before terminalizing the aggregate.
It never makes that child eligible for another rollback or apply. Missing,
unreadable, corrupt, or nondurable rollback evidence cannot be acknowledged and
remains globally blocking. The rollback result matrix and fixtures apply this
rule to every rejection class; provider rejection never proves rollback
atomicity.

The rollback acknowledgment mapping is exhaustive for structurally valid
started children:

| Latest rollback child evidence | Pre-acknowledgment action | Acknowledgment effect |
|---|---|---|
| `accepted` + `allDesired` | `rollbackAcknowledge` | Terminal receipt; no resource denial |
| Any non-clean first usable complete observation | `rollbackReconcile` | Ambiguity acknowledgment rejected; global block retained |
| Any rejection + reconciled usable complete observation | `rollbackAcknowledgeAmbiguity` | Permanent affected-resource denial, then terminal receipt |
| `accepted` + reconciled `allPrior` or `mixedOrDivergent` | `rollbackAcknowledgeAmbiguity` | Permanent affected-resource denial, then terminal receipt |
| `unknown` + reconciled usable complete observation | `rollbackAcknowledgeAmbiguity` | Permanent affected-resource denial, then terminal receipt |
| Any outcome + missing/unreadable observation | `rollbackReconcile` or `manualInspection` | Acknowledgment forbidden; global block retained |

Authentication and throttle rejection may require reauthorization or delayed
read-only reconciliation, but never a second rollback dispatch and never bypass
the mandatory reconciliation/denial rows.

A later reconcile commits a new digest and makes every older acknowledgment
stale; stale input returns exit 8/`stateInspect` without a state change. Cancellation
or crash before the acknowledgment CURRENT/AUTHORITY commit leaves the
aggregate pending. After a verified commit, repeating the identical command is
idempotent and returns the existing terminal receipt. Output failure does not
lose the digest or terminal state: `rollback-inspect` returns the latest digest
and receipt. Repeated reads, stale acknowledgments, cancellation, every commit
cut point, and idempotent retry are acceptance fixtures.

`rollback-resume --manifest-digest` is intentionally non-dispatching: after all
started children are reconciled, it requires a current writer-capable profile,
advertiser/safety-read allowlists, valid credentials, and a fresh authorization
fingerprint; it then performs the fixed authenticated safety reads and commits
their immutable observation before producing output. Auth, throttle, transport,
cancellation, and malformed-read failures retain the consumed aggregate and
map to rollback-recovery actions without a manifest. Resources still at the
post-apply desired status become actionable children; resources already at the
recorded prior target are reported as externally satisfied and omitted, never
encoded as no-op children. If no actionable child remains, resume emits a
terminal `RollbackResult` with no manifest; otherwise it emits a new canonical
all-actionable manifest for the untouched remainder. That new manifest requires a new digest
confirmation and separate `rollback-execute`; the consumed manifest is never
resumed in place. Reconcile never terminalizes or resumes by itself; resume
requires the current acknowledged terminal receipt. Output/durability failures
and crash cut points follow the same
authoritative-generation rules as apply.

### State lifecycle, recovery, migration, and retention

- Every lifecycle command resolves `canonicalStateParent`, acquires
  `canonicalStateParent/writer-mutation.lock`, and follows the locked
  snapshot/commit protocol above. Legacy discovery occurs only after lock
  acquisition and follows the explicit recovery-command exceptions above.
  `state initialize` creates the first lineage/epoch/AUTHORITY only when the
  canonical parent contains no CURRENT, AUTHORITY, epoch, checkpoint, backup,
  quarantine, migration/INTENT, or other state evidence beyond the permitted
  bootstrap lock; a missing
  AUTHORITY beside any state evidence is corruption, not a fresh install.
- `state inspect` is non-dispatching and emits a sanitized inventory/digest of
  its exact locked canonical generation and every cataloged legacy candidate;
  it remains available when canonical authority is absent or structurally
  invalid. When exactly one canonical nonterminal INTENT and its phase chain
  validate, inspect also emits the closed non-secret `pendingMigration` object:
  `migrationDigest`, `sourceRootId`, `migrationPhase`, and
  `resumeAcknowledgmentRequired: true`. This is the complete cold-handoff tuple
  for `state migrate-legacy --resume-migration-digest`; it contains no path,
  free text, secret, or caller-controlled value. A missing, corrupt, unreadable,
  or competing INTENT is reported only as a bounded issue class and
  `manualInspection`, never as a resumable tuple. A completed INTENT emits no
  pending tuple because ordinary canonical operation is no longer blocked.
- `state backup` first commits a checkpoint, then holds the lock while creating
  one self-contained owner-only bundle containing AUTHORITY proof, checkpoint,
  the checkpoint-to-CURRENT chain, every live claim/tombstone, unresolved
  journal and block, and byte-for-byte copies of every required recovery
  segment. A canonical manifest hashes every member; exact size and free space
  are checked before writing. A backup with only one generation or dangling
  external paths is invalid.
- In-place `state restore` is recovery, never rollback. The bundle lineage,
  epoch, generation, root, checkpoint, mutation disposition, unresolved-block
  digest, and wall-clock high-water must exactly equal the independently stored
  current AUTHORITY anchor. Only then may restore rebuild the same latest state
  by copy-validate-swap; it never merges and never lowers any counter. An older
  valid backup, a bundle newer/different from AUTHORITY, or absence/corruption
  of AUTHORITY is rejected and the candidate/current evidence is preserved for
  quarantine/manual inspection. Restore is permitted only while mutation
  authority is still `enabled`; quarantine entry is an irreversible boundary.
  Thus a stale backup cannot erase later claims.
- `state inspect` emits a canonical `inspectionDigest` over schema, canonical
  state-root identity, CURRENT/AUTHORITY roots, mutation disposition, bounded
  issue classes, and every candidate artifact digest. It is stable only while
  that locked snapshot is unchanged. `state quarantine --inspection-digest
  <sha256> --reason structural-corruption|suspected-whole-parent-rollback|
  post-reset-candidate-drift
  --ack-permanent-mutation-disable` accepts only the exact latest digest and
  explicit permanent-disable acknowledgment. `structural-corruption` is valid
  only when that inspection includes at least one closed evidence class:
  `currentInvalid`, `authorityInvalid`, `generationChainInvalid`,
  `requiredAncestorMissing`, `rootIdentityMismatch`, or
  `legacyOrSplitStateDetected`; a healthy inspection cannot select it. The
  suspected-rollback reason is valid for structurally valid state and is the
  mandatory operator path after a known or suspected whole-parent/APFS/VM/
  system-image restore. `post-reset-candidate-drift` is valid only for the
  exact blocked-authority/current-seal drift predicate defined above and is
  rejected for initial quarantine or any enabled lineage.
- Quarantine stabilizes legacy evidence after validating its input inspection
  digest. For every candidate with an exact descriptor-compatible safe regular
  lock, it acquires that existing lock after the canonical lock in compiled
  root-ID order and holds all acquired locks through sealing. Busy compatible
  locks return `retryLater` and cannot be bypassed. If any candidate's lock is
  absent, corrupt, unreadable, or descriptor-incompatible, quarantine requires
  literal `--ack-source-quiesced`; this acknowledges that the operator stopped
  legacy processes and externally made every unlockable source quiescent, but
  does not claim an OS lock. After lock acquisition or acknowledgment, the
  gateway performs a complete bounded no-follow scan and requires the same
  device/inodes, ordered members, metadata, and digests as the supplied
  inspection. It copies only from those opened descriptors, then repeats the
  complete scan before seal publication. Any pre-copy or post-copy mismatch,
  disappearing member, lock replacement, or instability discards unpublished
  staging when safe and returns exit 8/`manualInspection`; an already committed
  permanent block remains. Thus no quarantine seal claims a coherent legacy
  snapshot unless compatible locks held it stable or the explicit quiescence
  prerequisite plus identical pre/post scans established stability within the
  trusted-effective-user boundary.
- Quarantine is intentionally irreversible in slice one. Exact restore or
  repair must complete before initial enabled-lineage entry. There is no
  unquarantine command and no transition from a quarantine disposition to
  `enabled`. For initial entry when CURRENT and AUTHORITY remain writable, the
  gateway first commits and verifies
  `mutationAuthority=permanentlyBlockedQuarantine` with the reason,
  inspection digest, acknowledgment, and global dispatch block. If structural
  corruption makes that commit impossible, the preexisting
  `storageIntegrityUnknown` is already dispatch-blocking; the sealed manifest
  records `blockCommitUnavailableDueToCorruption`, and the explicit
  acknowledgment authorizes preservation/reset only, never re-enablement. It then
  copies bounded source evidence byte-for-byte into an owner-only staging
  directory under `canonicalStateParent/quarantine/`. Its closed schema-v1 manifest
  records reason enum, lineage/epoch, CURRENT and AUTHORITY digests,
  inspection digest, seal sequence, predecessor seal/chain root when present,
  maintenanceBaseRoot, stabilization method per candidate, quiescence
  acknowledgment when required, every source and lock device/inode identity,
  ordered member path/size/SHA-256 entries, and predecessor root. The canonical manifest digest uses
  domain `tiktok-business-gateway.quarantine.v1` plus a zero byte. The gateway
  fsyncs members and staging directory, renames no-replace to
  `quarantine/<quarantineDigest>/`, fsyncs the parent, verifies the seal, then
  commits `mutationAuthority=permanentlyBlockedQuarantined` referencing that digest when the
  source authority can accept a commit. Otherwise the independently sealed
  quarantine plus every unchanged corrupt source is the only permitted reset
  input. It never deletes or mutates source evidence.
- Re-quarantine from `permanentlyBlockedUnknownPriorState` follows the
  replacement-seal cycle above and skips the initial
  `permanentlyBlockedQuarantine` commit because authority is already
  permanently blocked. Initial and replacement seals share the same canonical
  manifest/digest schema; replacement-only predecessor, sequence, chain, and
  maintenance-base fields are mandatory and initial-only null values are
  canonical. No seal replaces or deletes its predecessor.
- Quarantine is non-network and follows the command matrix below. A crash before
  the permanent-block commit changes nothing; afterward startup remains
  permanently dispatch-blocked and deterministically resumes sealing from the
  bounded staging artifact. After seal publication but before the final CURRENT
  commit, startup validates and links the exact seal; after the final commit,
  repeating identical inputs returns the existing receipt. Conflicting staging,
  source drift, seal mismatch, or any durability uncertainty remains
  `storageIntegrityUnknown`/`manualInspection` and cannot reset or re-enable
  until a new inspection and successful replacement-seal commit establish the
  current quarantine digest. Mutation never re-enables.
- `state reset` requires the exact current `--quarantine-digest` and literal
  `--ack-permanent-mutation-disable`; it never restores mutation authority. It
  validates the sealed artifact, seal-chain root, maintenanceBaseRoot, and
  quarantined predecessor, then creates a new epoch from that exact latest
  canonical root with durable
  `mutationAuthority=permanentlyBlockedUnknownPriorState`, carries every known
  prior seal/receipt, committed maintenance change, claim/tombstone,
  checkpoint/archive anchor, advertiser/resource unresolved block, and
  high-water, and sets a global dispatch block when
  the prior latest state cannot be enumerated completely. Before the atomic
  CURRENT/AUTHORITY switch the quarantined epoch remains authoritative; after
  it the new permanently blocked epoch is authoritative. A crash is resolved by
  those roots, and repeating the same digest is idempotent. AUTHORITY may move
  from enabled to blocked but never back. The new epoch supports inspection,
  receipt export, and only the commands in
  `postResetMaintenanceCommands.v1` while preserved candidates remain an exact
  match for the bound quarantine seal; drift closes that maintenance exception
  as defined above. Reader operation remains usable. Plan, apply, reconcile,
  rollback, restore, initialize, migrate, rotation, and all mutation dispatch
  remain permanently disabled for this lineage. Slice one has no bypass. Exact
  latest-state restoration must occur before the first irreversible reset, or a
  separately designed external authoritative adjudication system is required
  to regain mutation authority. Re-quarantine/re-reset cycles only restore
  maintenance reachability and never satisfy that requirement.
- `state migrate-legacy` is the digest-bound, phase-specific locked
  copy-validate-activate-retire flow above. Fresh start requires absent canonical
  authority; exact INTENT resume permits only its phase-bound absent or exact
  canonical target. It preserves all authority and replay state and never sends
  network traffic. Actual split state and newer, unknown, corrupt, or
  non-cataloged schemas fail closed to inspect/quarantine; there is no fallback
  or merge. API-version migration requires a new catalog and official evidence.
- Active regular state is capped at 512 MiB, with an absolute 576 MiB root cap;
  it also caps 1,000 unclaimed plan/rollback issuance records, 50,000 claim
  digests, 4 MiB per plan journal, 16 inline observation rounds, and 80 inline
  observation records per plan. The final
  64 MiB is reserved exclusively for authoritative outcome,
  observation, receipt, reconciliation, and archival-anchor commits. At 70% of
  any regular cap it emits a safe capacity warning; at 80% it rejects new plans
  and new apply/rollback claims before token/network. At 95% and even after the
  512 MiB regular cap is reached, bounded `reconcile` and
  `rollback-reconcile` remain permitted from the recovery reserve; mutation,
  planning, and unrelated reads remain forbidden. Before each recovery network
  call, the gateway proves room for the maximum response plus two generation
  commits. If the reserve cannot cover both, it performs no network call and
  requires `archiveState`, never epoch reset merely for capacity.
- The 16-round/80-record limits bound full observations retained inline, not
  the number of safe recovery attempts. Before another round would exceed a
  limit, `state archive-recovery --plan-digest ... --output <path>` writes and
  fsyncs a bounded owner-only immutable segment containing every displaced
  observation and chain proof, verifies its digest, then atomically replaces
  those inline records with a digest/path/count anchor while retaining the
  latest full observation. Missing, moved, or corrupt required segments cause
  `storageIntegrityUnknown`; successful segmentation frees inline capacity and
  reconciliation may continue. Each segment is capped at 64 MiB and paths are
  explicit; the operator controls external archival retention and free space.
- `state checkpoint` commits a self-contained generation containing every live
  authorization fact, exact replay tombstone, permanent resource-denial
  tombstone, unresolved record/block, latest
  inline observation, required external-segment digest/path, capacity counter,
  wall-clock high-water, and a domain-separated `historyCommitment` over the
  prior checkpoint commitment plus every ordered generation root since it. The
  history hash uses SHA-256 with
  `tiktok-business-gateway.state-history.v1` plus a zero byte.
  Unclaimed issuance records may be removed only after same-boot continuous
  expiry or boot-session invalidation; apply/execute requires the exact issuance
  record, so a removed artifact deterministically returns `newPlan`.
  After CURRENT and AUTHORITY both name and verify this checkpoint, startup may
  use it as the oldest required root. Before both advances, no predecessor is
  eligible for deletion.
- Garbage collection is a locked, non-authoritative cleanup after checkpoint:
  delete only pre-checkpoint generation/staging files not referenced by the
  checkpoint, backup, quarantine, or required recovery segment; fsync the
  directory after each bounded batch. A crash before checkpoint authority
  deletes nothing; a crash during GC leaves a valid self-contained checkpoint
  and safely repeatable remaining deletions. Never delete claims, replay or
  resource-denial tombstones,
  unresolved evidence/blocks, AUTHORITY, the active checkpoint, or later
  generations. Physical capacity uses the greater of logical bytes and
  filesystem allocated bytes for every file under the active root, including
  staged/checkpoint/GC-pending files; bytes are freed only after unlink and
  directory fsync. External segments/backups are reported separately.
- Archive is a two-phase noninteractive workflow. `state archive-plan --output
  <path>` locks one healthy snapshot and writes a canonical schema-v1 plan with
  lineage/epoch, CURRENT/AUTHORITY roots, ordered eligible terminal record
  digests, excluded active/ambiguous records, projected tombstones, byte counts,
  expiry of 10 minutes, and a domain-separated
  `tiktok-business-gateway.archive-plan.v1` SHA-256 digest. It performs no
  compaction and no archive write. `state archive --plan <path>
  --confirm-digest <sha256> --output <path>` requires that full plan digest and
  an unchanged locked snapshot. It writes and verifies the owner-only archive,
  then replaces only the planned terminal journals with exact digest-keyed
  replay tombstones plus chain/root evidence, commits CURRENT and AUTHORITY,
  checkpoints, and runs GC. It never removes an active or ambiguous record.
  Failure before the authoritative compaction commit leaves state unchanged; a
  complete matching archive may be reused. A crash after archive publication
  but before the commit is detected by plan/archive digests and safely resumed;
  after commit, repeating the same plan returns the existing archive receipt.
  No deletion precedes verified CURRENT/AUTHORITY authority. `state rotate-epoch` requires
  no unresolved work, a verified owner-only archive output, and confirmation of
  its digest, and is forbidden when AUTHORITY is permanently blocked; it seals
  a healthy old epoch, starts a new one in the same enabled lineage, and makes
  every old plan invalid by epoch mismatch. Backup/archive/quarantine outputs are explicit
  secure paths outside the active root and are size/free-space checked before
  writing. Failure leaves `CURRENT` unchanged.

### Cancellation contract for every writer command

Cancellation is a closed command contract, not an implementation callback.
Before lock acquisition it returns immediately under the lock rule above. Once
the lock is held, receipt of cancellation starts the same absolute continuous-
time deadline `C + 2 seconds` for every writer command. No mutation POST starts
after C. Until the deadline, a command may cancel an active read, finish its
current bounded copy chunk, or start at most one already-prepared authoritative
commit identified below. At the deadline it invalidates active transports,
discards late callbacks, starts no network, copy chunk, file publication,
commit, output write, or cleanup, and keeps the last reopened-and-verified
CURRENT/AUTHORITY authoritative.

An already-entered write, `fsync`, rename, or directory `fsync` is not safely
interruptible. The process retains the lock and emits no result until that
syscall returns and authority is verified; late success or failure follows the
row's post-cut result. External termination is a crash, and startup uses only
verified authority. Atomic output keeps the prior target unless its rename was
already entered; stdout may contain a truncated prefix and is never restarted.
Cancellation before any authoritative change emits no stdout and returns exit
8/`retryLater` unless the row names a workflow-specific recovery action. After
an authoritative change, the matching result schema reports the last verified
state and action. Repeating the exact digest-bound command is idempotent or
resumes only the non-dispatching work named below.

| Writer command | Authoritative cancellation cut and allowed continuation | Result/retry after cancellation |
|---|---|---|
| `--help` | No state cut; stop rendering by deadline | Exit 8; rerun |
| `--version` | No state cut; stop rendering by deadline | Exit 8; rerun |
| `catalog show` | No state cut; stop atomic/stdout output by deadline | `utilityResult`/`retryLater` |
| `config validate` | No state cut; stop parsing/output by deadline; no secrets | `utilityResult`/`retryLater` |
| `config status` | No state cut; stop local checks/output by deadline; no secret values | `utilityResult`/`retryLater` |
| `status plan` | Cancel/clamp active safety read; before `planIssued` no plan exists; an entered `planIssued` commit may finish | Before cut `retryLater`; after cut identical request digest returns stored plan via `applyResult`/`stateInspect` |
| `status apply` | Before claim the plan remains usable; after claim use the post-dispatch algorithm and no later child starts | `newPlan`, `reconcile`, or `stateInspect` from durable axes; never redispatch |
| `status reconcile` | Cancel active read; an entered observation commit may finish; no dispatch | Existing or new `applyResult` with `reconcile`, auth/throttle variant, or `stateInspect` |
| `status ambiguity-close` | Before close commit state remains pending; entered close/tombstone commit may finish | `closeAmbiguityWithoutDispatch` before cut; idempotent `none` after verified cut |
| `status rollback-inspect` | No state mutation; stop snapshot/output by deadline | `rollbackResult`/`retryLater`; rerun |
| `status rollback-plan` | No network/secrets; before `rollbackIssued` no manifest exists; entered issuance commit may finish | Before cut `retryLater`; after cut identical inputs return stored manifest via `rollbackResult`/`stateInspect` |
| `status rollback-execute` | Before claim manifest remains usable; after claim identical to apply and no later child starts | `newRollbackPlan`, `rollbackReconcile`, or `stateInspect`; never redispatch |
| `status rollback-reconcile` | Cancel active read; entered observation commit may finish; no dispatch | Existing/new `rollbackResult` with rollback reconcile/auth/throttle action or `stateInspect` |
| `status rollback-acknowledge` | Before acknowledgment commit aggregate remains pending; entered receipt/denial commit may finish | `rollbackAcknowledge` or `rollbackAcknowledgeAmbiguity` before cut; idempotent `none` after cut |
| `status rollback-resume` | Cancel active safety read; entered observation or new-manifest issuance commit may finish; no dispatch | `rollbackResume`, rollback recovery action, or stored result/manifest after cut |
| `receipt export` | No state mutation; stop output by deadline | `applyResult`/`retryLater`; rerun |
| `state initialize` | Before initial CURRENT/AUTHORITY commit canonical authority remains absent and only bootstrap artifacts may exist; entered commit may finish | `lifecycleResult`/`retryLater` before cut; idempotent initialized result after cut |
| `state inspect` | No state mutation; stop scan/output by deadline | `lifecycleResult`/`retryLater`; rerun |
| `state migrate-legacy` | Fresh start before INTENT leaves canonical authority absent and source unchanged; afterward each no-replace phase receipt is the cut, and digest-bound resume follows only its phase predicates, including no source-lock recreation after `sourceLockRetired` | Before INTENT `retryLater`; after INTENT `completeMigration`; inspect exposes the resume digest and exact resume never dispatches |
| `state clock-status` | No state mutation; stop scan/output by deadline | `lifecycleResult`/`retryLater`; rerun |
| `state checkpoint` | Before checkpoint commit state is unchanged; entered CURRENT/AUTHORITY commit may finish | `retryLater` before cut; idempotent `none` after cut |
| `state backup` | A checkpoint commit may remain; stop starting copy chunks/output publication by deadline | `retryLater`; exact retry reuses checkpoint and complete matching staged bundle |
| `state restore` | Before activation state is unchanged and candidate stays non-authoritative; entered exact-root switch may finish | `stateInspect`; exact retry validates/reuses candidate or returns restored receipt |
| `state quarantine` | Source-lock acquisition/pre-copy revalidation precede staging; initial entry may commit the permanent block before copying, while post-reset re-quarantine keeps old blocked authority until the replacement-seal CURRENT/AUTHORITY commit; after a cut stop new chunks and retain locks through the active chunk/post-scan cut | Before authoritative cut `retryLater`; after initial block `completeQuarantine`; replacement retry reuses exact staging or latest inspection; neither path re-enables |
| `state reset` | Before epoch switch the current initial/replacement seal remains authoritative; entered switch carries the exact maintenanceBaseRoot and complete seal chain into the next blocked epoch | `stateInspect`; exact current-seal retry returns or completes the blocked reset receipt; old seal rejects |
| `state archive-plan` | No state mutation; stop plan/output by deadline | `lifecycleResult`/`retryLater`; rerun |
| `state archive` | Before compaction commit state is unchanged and a verified archive may remain; entered compaction commit may finish; no new GC batch starts after deadline | `retryArchive`; exact retry reuses archive and resumes compaction/GC without deleting uncommitted records |
| `state archive-recovery` | Before anchor commit inline state is unchanged and a verified segment may remain; entered anchor commit may finish | `retryArchive`; exact retry reuses segment and completes/verifies anchor |
| `state rotate-epoch` | Before epoch switch old epoch remains authoritative; entered sealed switch may finish | `stateInspect`; exact retry returns the existing rotation receipt |

No lifecycle command ignores cancellation after a cut. It may only finish an
already-entered uninterruptible syscall; every other continuation stops at the
deadline and is resumed by the exact idempotent command described above.

## 9. Validation, errors, and exits

Validation order is CLI grammar, safe file/config parsing, catalog lookup,
capability/profile/advertiser/operation authorization, typed input and bounds,
fixed request construction, then credential resolution and dispatch.

Errors are stable JSON on stderr with safe fields only:

```json
{"error":{"kind":"providerThrottled","operation":"campaigns.list","httpStatus":200,"providerCode":40100,"requestId":"safe-request-id","retryable":false,"action":"retryLater"}}
```

Provider messages are treated as tainted and pass key/value and known-secret
redaction. Raw response bodies, headers, queries, and request bodies are never
emitted. Invalid/missing envelopes and oversized error bodies are protocol
errors.

| Exit | Meaning |
|---:|---|
| 0 | Complete read, terminal durable no-op, or accepted writer outcome with all desired observed and durable state. |
| 2 | Usage, schema, validation, or non-secret configuration error. |
| 3 | Authentication or permission failure. |
| 4 | Permanent provider rejection before claim. Post-dispatch rejection never terminalizes from one all-prior observation without official atomic-rejection evidence. |
| 5 | Throttle or transient reader/pre-claim safety-read failure. |
| 6 | Transport/protocol failure proven before claim or writer dispatch. |
| 7 | Partial bounded read result. |
| 8 | Expired/stale/replayed plan, unsafe clock, coordination busy, ambiguous dispatch, external-race review, output loss, capacity cutoff, or storage integrity failure. |

Writer stdout uses a closed discriminated union; no universal nullable
plan/rollback field exists:

| `kind` | Commands | Required identity/state fields | Forbidden fields |
|---|---|---|---|
| `applyResult` | `status plan/apply/reconcile/ambiguity-close`, `receipt export` | `command`, `planDigest`, `stateEpoch`, `generation`, `journalState`, `dispatchEvidence`, `providerOutcome`, `observation`, `exit`, `requiredAction`; plan artifact is present only for successful plan and receipt artifact only for export | Every rollback, quarantine, backup, archive, and lifecycle-only field |
| `rollbackResult` | `status rollback-inspect/plan/execute/reconcile/acknowledge/resume` | `command`, `parentPlanDigest`, `stateEpoch`, `generation`, `rollbackState`, `exit`, `requiredAction`; `manifestDigest` is required for execute/reconcile/acknowledge/resume and forbidden for inspect; `emittedManifestDigest` is present only when plan/resume emits a manifest; `observationDigest` is required whenever the command confirms or emits an observation | Apply journal axes unrelated to rollback and every lifecycle-artifact field |
| `lifecycleResult` | Every `state` command | `command`, `stateEpochBefore`, `stateEpochAfter`, `authorityDisposition`, `generationBefore`, `generationAfter`, `exit`, `requiredAction`; before/after epoch and generation may be null only where canonical authority is absent or unreadable on initialize, inspect, migrate-legacy, or quarantine; successful initialize/migrate supplies non-null after fields; non-mutating commands repeat before as after; command-specific artifact/digest fields follow the table below | Plan, parent-plan, manifest, dispatch, provider-outcome, and observation fields |
| `utilityResult` | Writer `catalog show`, `config validate`, `config status` | `command`, `exit`, `requiredAction` | All state, network, plan, rollback, and lifecycle fields |

For `lifecycleResult`, `inspectionDigest` is present only for inspect,
migrate-legacy, and quarantine; `authorityDigest` only for clock-status,
backup, restore, migrate-legacy, and authority-changing commands;
`migrationDigest`, `sourceRootId`, and `migrationPhase` only for
migrate-legacy; `pendingMigration` only for inspect with exactly one valid
nonterminal canonical INTENT and contains only `migrationDigest`,
`sourceRootId`, `migrationPhase`, and `resumeAcknowledgmentRequired`;
`sourceStability` only for inspect and quarantine;
`artifactDigest` only for successful backup, quarantine, archive, and
archive-recovery; `archivePlanDigest` only for archive-plan/archive; and
`quarantineDigest` only for quarantine/reset. Blocked-authority inspect,
quarantine, and reset additionally expose `currentQuarantineSealDigest`,
`quarantineSealSequence`, and `maintenanceBaseRoot`; replacement quarantine
alone exposes `predecessorQuarantineDigest`. A field listed as
command-specific is required on that successful command and forbidden
otherwise. Failed commands emit the error envelope on stderr and no partial
stdout result unless an authoritative commit already occurred, in which case
the matching workflow result describes the last verified state.

`requiredAction` is one closed global enum, with each result kind restricted to
its subset:

- apply: `none`, `retryLater`, `newPlan`, `reconcile`, `reauthorizeThenReconcile`,
  `retryLaterThenReconcile`, `stateInspect`, `correctClock`,
  `closeAmbiguityWithoutDispatch`, `archiveState`, `manualInspection`;
- rollback: `none`, `retryLater`, `newRollbackPlan`, `rollbackReconcile`,
  `reauthorizeThenRollbackReconcile`, `retryLaterThenRollbackReconcile`,
  `rollbackAcknowledge`, `rollbackAcknowledgeAmbiguity`, `rollbackResume`,
  `stateInspect`, `correctClock`, `archiveState`, `manualInspection`;
- lifecycle: `none`, `retryLater`, `stateInspect`, `correctClock`,
  `completeMigration`, `completeQuarantine`, `retryArchive`,
  `manualInspection`;
- utility: `none`, `retryLater`, `manualInspection`.

Pre-result errors use the same JSON error envelope and exactly one of
`correctInput`, `reauthorize`, `retryLater`, `newPlan`, `newRollbackPlan`,
`correctClock`, `archiveState`, `stateInspect`, `completeMigration`, or
`manualInspection`. Any action
outside the result-kind subset, missing required identity, forbidden extra
field, or simultaneous result kinds is schema corruption and fails closed.
Top-level `--help` and `--version` are deterministic human text and are the only
writer outputs outside this JSON union.

Pre-claim classification is a closed enum and this table is authoritative and
mutually exclusive. No summary table or transport layer may override it.

| Pre-claim result | Exit | Required action |
|---|---:|---|
| Invalid CLI/input/config/canonical form or mixed child classifications | 2 | `correctInput` |
| Authentication or permission rejection | 3 | `reauthorize` |
| Provider throttle | 5 | `retryLater` |
| Permanent provider rejection from a safety read | 4 | `correctInput` |
| Transient provider/HTTP failure, safe-read timeout after request start, or exhausted safe-read retries | 5 | `retryLater` |
| Transport failure or timeout proven before any request dispatch | 6 | `retryLater` |
| Malformed HTTP, oversized error, or malformed provider envelope | 6 | `manualInspection` |
| Stale/drift/catalog/profile-fingerprint/epoch mismatch | 8 | `newPlan` for apply; `newRollbackPlan` for rollback |
| Clock earlier than durable high-water or same-boot continuous-clock regression | 8 | `correctClock` |
| Boot-session mismatch | 8 | `newPlan` |
| Wall or continuous expiry exceeded | 8 | `newPlan` |
| Capacity threshold or insufficient worst-case reserve | 8 | `archiveState` |
| Writer-state I/O/integrity failure | 8 | `manualInspection` |
| State-lock contention | 8 | `retryLater` |
| Result/output delivery failure before claim | 6 | `retryLater` |

Post-claim classifications are closed enums. `childKind` is `noOp` or
`actionable`; `childState` is `untouched`, `dispatching`, `outcomeRecorded`,
`observed`, `reconciled`, `ambiguityPending`, `ambiguityClosed`, or
`noOpObserved`; `dispatchEvidence` is `none`,
`definitelyNotSent`, `possiblySent`, or `sent`; `providerOutcome` is
`notAvailable`, `accepted`, `rejectedPermanent`, `rejectedAuth`,
`rejectedThrottle`, or `unknown`; `observation` is `notAttempted`,
`allDesired`, `allPrior`, `mixedOrDivergent`, or `missingOrUnreadable`; and
`durability` is `durable` or `failedOrUnknown`. `recoveryCondition` is `none`,
`authBlocked`, `throttled`, or `transient`. `allPriorConfirmation` is
`notApplicable`, `awaitingLaterUsableConfirmation`, or `confirmed`; it is
`notApplicable` unless observation is `allPrior`.

Validate the following disjoint predicates before action lookup; every legal
tuple matches exactly one:

1. no-op is exactly
   `noOp/noOpObserved/definitelyNotSent/notAvailable/allDesired/none`;
2. untouched actionable is exactly
   `actionable/untouched/none/notAvailable/notAttempted/none`;
3. proven-unsent actionable is exactly
   `actionable/outcomeRecorded/definitelyNotSent/notAvailable/notAttempted/none`,
   is exempt from every dispatch-attempted rule, and maps only to exit
   8/`newPlan`;
4. dispatching is exactly
   `actionable/dispatching/possiblySent/unknown/notAttempted/none`;
5. response-known attempted state is actionable `outcomeRecorded`, `observed`,
   or `reconciled`, has `sent`, and has `accepted` or a rejection outcome;
6. response-unknown attempted state is actionable `outcomeRecorded`,
   `observed`, or `reconciled`, has `possiblySent` or `sent`, and has `unknown`.
7. `ambiguityPending` is actionable, has `possiblySent` or `sent`, preserves
   the provider outcome, has a usable complete observation, recovery `none`,
   and matches one `closeAmbiguityWithoutDispatch` row below; an `allPrior`
   instance additionally requires confirmation `confirmed`;
8. `ambiguityClosed` preserves the exact predicate-7 axes and additionally has
   a verified terminal receipt plus a permanent denial tombstone for every
   affected resource.

For predicates 5 and 6, `outcomeRecorded` has `notAttempted`; `observed` and
`reconciled` have another observation. Predicates 7 and 8 always have a usable
observation. A usable observation (`allDesired`,
`allPrior`, or `mixedOrDivergent`) requires recovery condition `none`; a
non-none recovery condition requires `notAttempted` or `missingOrUnreadable`.
For `allPrior`, awaiting confirmation requires a recorded first usable attempt;
confirmed requires a strictly later attempt sequence and at least two usable
all-prior observations. No child-state name or count of unreadable
reconciliation rounds substitutes for these fields.
Any tuple matching zero or multiple predicates is state corruption:
return exit 8/`manualInspection`, commit `storageIntegrityUnknown` when possible,
and block all writer dispatch. It must never reach a wildcard mapping.

After invariant validation, this matrix is total for every legal post-claim
tuple. Rows beginning `Possible/sent` apply only to predicate-5/6
`outcomeRecorded`/`observed`/`reconciled` states and exclude predicates 7-8.
When such a row selects `closeAmbiguityWithoutDispatch`, the writer first
commits and verifies the non-network `ambiguityPending` generation, then emits
the exact `ambiguityPending` row with the same action. No result action directly
authorizes rollback:

| Legal post-claim predicate, in precedence order | Exit | Required action |
|---|---:|---|
| Durability `failedOrUnknown` | 8 | `manualInspection` |
| Durable state but final result delivery failed | 8 | `stateInspect` |
| Exact no-op tuple | 0 | `none` |
| Actionable `untouched` or proven `definitelyNotSent` | 8 | `newPlan` |
| Possible/sent; no usable observation; recovery `authBlocked` | 3 | `reauthorizeThenReconcile` |
| Possible/sent; no usable observation; recovery `throttled` or `transient` | 8 | `retryLaterThenReconcile` |
| Possible/sent; no usable observation; recovery `none` | 8 | `reconcile` |
| Possible/sent; `accepted`; `allDesired` | 0 | `none` |
| Possible/sent; any rejection or `unknown`; `allDesired` | 8 | `closeAmbiguityWithoutDispatch` |
| Possible/sent; `rejectedAuth`; `allPrior`; confirmation awaiting | 3 | `reauthorizeThenReconcile` |
| Possible/sent; `rejectedThrottle`; `allPrior`; confirmation awaiting | 8 | `retryLaterThenReconcile` |
| Possible/sent; `accepted`, `rejectedPermanent`, or `unknown`; `allPrior`; confirmation awaiting | 8 | `reconcile` |
| Possible/sent; any provider outcome; `allPrior`; confirmation confirmed | 8 | `closeAmbiguityWithoutDispatch` |
| Possible/sent; any provider outcome; `mixedOrDivergent` | 8 | `closeAmbiguityWithoutDispatch` |
| Exact intact `ambiguityPending` with unchanged complete observation | 8 | `closeAmbiguityWithoutDispatch` |
| Exact durable `ambiguityClosed` with resource-denial tombstones | 8 | `manualInspection` |

The tables cover permanent pre-claim rejection, proven pre-dispatch transport
failure, timeout, malformed protocol, authentication rejection after possible
dispatch, throttling with desired readback, rejection with divergent state,
no-op, output failure, and durability failure. They are evaluated for every
child; a child not started because of deadline/cancellation has the exact legal
`untouched` tuple and requires `newPlan`.
Global durability and output rows precede child evaluation. Child results reduce
to one aggregate pair by this fixed highest-first precedence:
`manualInspection`, `closeAmbiguityWithoutDispatch`, `reauthorizeThenReconcile`,
`retryLaterThenReconcile`, `reconcile`, `stateInspect`, `archiveState`,
`correctClock`, `newPlan`, `retryLater`,
`reauthorize`, `none`.
There is no alternative aggregate action.

An exhaustive table-driven test enumerates the full Cartesian product, proves
each tuple is either rejected by exactly one invariant or mapped by exactly one
row, checks all multi-child reductions, and asserts every invalid tuple blocks
dispatch. A new enum case fails compilation or catalog validation until the
invariants, matrix, and fixtures are updated.

## 10. Rate limits, timeouts, and retries

- Catalog current official global defaults separately from the configured app
  tier. Default local reader policy is one in-flight request per profile and at
  most two starts/second; config may only lower it in slice one.
- Reader connect timeout is 10 seconds, one-page deadline 30 seconds, and total
  traversal/report deadline 120 seconds. Response-byte limits apply while
  streaming.
- Reads may retry at most twice with capped exponential backoff and injected
  jitter only for a transport failure proven pre-response or HTTP 5xx.
- Application throttle codes 40016/40100/40133 are not automatically retried
  because the response does not identify QPS, QPM, or QPD suspension. Return
  `retryLater`; honor a valid `Retry-After` only in a future reviewed policy.
- Writer mutation requests never retry for transport, HTTP, application,
  timeout, redirect, challenge, or throttle outcomes. Safety reads are bounded
  independently and cannot authorize a second dispatch.
- Limits are process-local. Aggregate concurrent CLI traffic remains a
  documented risk; no interprocess reader-rate database is introduced.

## 11. CLI contract and visible flows

The following is the exhaustive slice-one grammar. No other command path or
flag is valid. Brackets mean optional; alternatives are separated by `|`.
Options after a command path are order-independent but may appear only once.

```text
CONFIG := [--config <path>]
OUTPUT := [--output <path>]
LOCK := [--lock-timeout-ms <integer-0-through-2000>]
PROFILE := --profile <profile-id> CONFIG OUTPUT
RECOVERY := [--recovery-profile <profile-id>] CONFIG OUTPUT LOCK
PAGE := [--page <positive-int>] [--page-size <catalog-bounded-positive-int>]
     | --all-pages --max-pages <integer-1-through-100>
       [--page-size <catalog-bounded-positive-int>]
QUARANTINE_REASON := structural-corruption | suspected-whole-parent-rollback
                   | post-reset-candidate-drift
MIGRATION := --inspection-digest <sha256> --source-root-id <legacy-root-id>
           | --resume-migration-digest <sha256>

tiktok-business-gateway-reader --help
tiktok-business-gateway-reader --version
tiktok-business-gateway-reader catalog show OUTPUT
tiktok-business-gateway-reader config validate CONFIG OUTPUT
tiktok-business-gateway-reader config status --profile <profile-id> CONFIG OUTPUT
tiktok-business-gateway-reader auth status PROFILE
tiktok-business-gateway-reader advertisers list PROFILE
tiktok-business-gateway-reader advertisers get PROFILE --advertiser-id <advertiser-id>
tiktok-business-gateway-reader campaigns list PROFILE --advertiser-id <advertiser-id> [--request-file <path>] PAGE
tiktok-business-gateway-reader adgroups list PROFILE --advertiser-id <advertiser-id> [--request-file <path>] PAGE
tiktok-business-gateway-reader ads list PROFILE --advertiser-id <advertiser-id> [--request-file <path>] PAGE
tiktok-business-gateway-reader reports integrated PROFILE --request-file <path>

tiktok-business-gateway-writer --help
tiktok-business-gateway-writer --version
tiktok-business-gateway-writer catalog show OUTPUT
tiktok-business-gateway-writer config validate CONFIG OUTPUT
tiktok-business-gateway-writer config status --profile <profile-id> CONFIG OUTPUT
tiktok-business-gateway-writer status plan --profile <profile-id> CONFIG --request-file <path> --output <path> LOCK
tiktok-business-gateway-writer status apply CONFIG --plan <path> --confirm-digest <sha256> OUTPUT LOCK
tiktok-business-gateway-writer status reconcile --plan-digest <sha256> RECOVERY
tiktok-business-gateway-writer status ambiguity-close --plan-digest <sha256> --observation-digest <sha256> --ack-permanent-resource-disable OUTPUT LOCK
tiktok-business-gateway-writer status rollback-inspect --plan-digest <sha256> --selection-file <path> --output <path> LOCK
tiktok-business-gateway-writer status rollback-plan --plan-digest <sha256> CONFIG --selection-file <path> --observation-digest <sha256> --ack-external-origin-risk --output <path> LOCK
tiktok-business-gateway-writer status rollback-execute CONFIG --manifest <path> --confirm-digest <sha256> --ack-external-origin-risk OUTPUT LOCK
tiktok-business-gateway-writer status rollback-reconcile --manifest-digest <sha256> RECOVERY
tiktok-business-gateway-writer status rollback-acknowledge --manifest-digest <sha256> --observation-digest <sha256> --ack-external-origin-risk OUTPUT LOCK
tiktok-business-gateway-writer status rollback-resume --manifest-digest <sha256> [--recovery-profile <profile-id>] CONFIG --output <path> LOCK
tiktok-business-gateway-writer receipt export --plan-digest <sha256> --output <path> LOCK
tiktok-business-gateway-writer state initialize OUTPUT LOCK
tiktok-business-gateway-writer state inspect --output <path> LOCK
tiktok-business-gateway-writer state migrate-legacy MIGRATION --ack-legacy-writer-retired --output <path> LOCK
tiktok-business-gateway-writer state clock-status --output <path> LOCK
tiktok-business-gateway-writer state checkpoint OUTPUT LOCK
tiktok-business-gateway-writer state backup --output <path> LOCK
tiktok-business-gateway-writer state restore --backup <path> --confirm-authority-digest <sha256> OUTPUT LOCK
tiktok-business-gateway-writer state quarantine --inspection-digest <sha256> --reason <quarantine-reason> --ack-permanent-mutation-disable [--ack-source-quiesced] OUTPUT LOCK
tiktok-business-gateway-writer state reset --quarantine-digest <sha256> --ack-permanent-mutation-disable OUTPUT LOCK
tiktok-business-gateway-writer state archive-plan --output <path> LOCK
tiktok-business-gateway-writer state archive --plan <path> --confirm-digest <sha256> --output <path> LOCK
tiktok-business-gateway-writer state archive-recovery --plan-digest <sha256> --output <path> LOCK
tiktok-business-gateway-writer state rotate-epoch --archive <path> --confirm-digest <sha256> OUTPUT LOCK
```

Grammar and incompatibility rules are normative:

- `--help` and `--version` are top-level, mutually exclusive, and accept no
  other flag or argument. There are no short flags, combined flags, positional
  arguments, aliases, interactive prompts, stdin path `-`, or `--` passthrough.
- Unknown, duplicate, missing-value, out-of-range, or command-inapplicable
  flags fail with exit 2 before config, secrets, state, or network.
- Config resolution order is explicit `--config`, then
  `TIKTOK_BUSINESS_GATEWAY_CONFIG`, then the default path. The environment value
  is only a path. `--config` is invalid on a grammar row without `CONFIG`.
- `--output` is required where written literally and optional only through
  `OUTPUT`/`PROFILE`/`RECOVERY`. Input and output paths must resolve to distinct
  descriptor identities; path aliases, hard-link identity, and an output inside
  `canonicalStateParent` are rejected. Optional output omission selects
  stdout under the delivery rules below; required output omission is exit 2.
- `--profile` and `--recovery-profile` are mutually exclusive. Recovery profile
  is valid only on the three grammar rows that show it. Without it, the bound
  original profile is used. The selected config uses the normal resolution
  order.
- `PAGE` is accepted only by the three resource-list commands. `--page` cannot
  combine with `--all-pages` or `--max-pages`; `--max-pages` requires
  `--all-pages`. Omitting PAGE requests page 1 at the catalog default size.
  Resource-list request files contain only cataloged filters/field selections
  and cannot contain advertiser or pagination controls. Report pagination is
  exclusively inside its request file, so report commands reject every PAGE
  flag.
- All `<sha256>` values are exactly 64 lowercase hexadecimal characters.
  `--ack-permanent-resource-disable` and
  `--ack-permanent-mutation-disable` and `--ack-external-origin-risk` are
  distinct literal value-less flags valid only on their shown commands.
  `--observation-digest` always confirms the domain-separated observation from
  the exact locked snapshot and never doubles as a risk acknowledgment.
- `<legacy-root-id>` is exactly one compiled identifier from
  `legacyStateRoots.v1`; caller-supplied source paths are forbidden. Migration
  fresh start rejects a stale inspection digest, zero or multiple
  evidence-bearing roots, any canonical authority, existing INTENT, and any
  source not accepted by that root ID's compiled schema descriptor. Resume
  instead requires only `--resume-migration-digest`, an existing valid INTENT
  at that digest-derived canonical location, and exactly the canonical/source
  predicates for its latest phase; inspection-digest and source-root flags are
  forbidden on resume and are derived from INTENT. Fresh and resume alternatives
  are mutually exclusive and complete. Resume never reapplies the fresh-start
  absent-authority rule after activation.
  `--ack-legacy-writer-retired` is a distinct literal value-less flag valid
  only for migrate-legacy; it records the operator's package/process retirement
  assertion and never substitutes for acquiring the compatible legacy lock.
- `--ack-source-quiesced` is valid only for quarantine and is required exactly
  when the bound inspection contains at least one candidate whose existing
  source lock cannot be safely acquired because it is absent, corrupt,
  unreadable, or descriptor-incompatible. It cannot bypass a busy compatible
  lock and never substitutes for the mandatory pre/post-copy digest scans.
- Quarantine reason compatibility is exact: `post-reset-candidate-drift`
  requires `permanentlyBlockedUnknownPriorState`, the current seal named by
  AUTHORITY, and a matching inspection issue; the other two reasons cannot
  start a replacement-seal cycle. Reset accepts only AUTHORITY's current seal
  digest, never a predecessor from the retained chain.
- `LOCK` is valid on every writer command that reads or changes writer state
  and nowhere else. Omission means 2,000 ms; the range is 0...2,000 ms and
  changes only lock acquisition, never network or cancellation deadlines.
- `status plan`, rollback planning/inspection/resume, backup, archive planning/execution, and
  recovery-segment export require atomic file output. Apply/reconcile/close,
  rollback execute/reconcile/acknowledge, initialization/checkpoint/restore/
  quarantine/reset/rotation may use stdout or optional atomic output.
- Reader profiles are rejected by the writer binary and writer profiles by the
  reader binary before secret resolution. Writer has no `auth`, advertiser, or
  generic read command; reader has no status, receipt, state, or mutation
  command.
- Slice one ships exactly the reader and writer products named above. The
  unqualified `tiktok-business-gateway` compatibility product, executable,
  symlink, wrapper, alias, and deprecation route are absent; invoking that name
  is an operating-system command-not-found outcome outside this CLI contract.

A command without `--output` attempts to stream exactly one versioned JSON
document to stdout, but the completeness guarantee applies only when the write
finishes successfully. Broken pipes, cancellation, or filesystem/stdout errors
may leave a truncated prefix; the process stops writing, emits one sanitized
`outputDeliveryFailed` diagnostic to stderr, never writes a replacement JSON,
and exits 6 for reader/pre-claim work or 8/`stateInspect` after a durable writer
claim. Durable writer state remains authoritative and never permits redispatch.

Every machine-data command supports `--output <path>` for atomic delivery and
then writes no stdout. It descriptor-validates the target directory, writes a
bounded owner-only same-directory temporary file, fsyncs and closes it,
atomically renames it over only the explicitly named output, fsyncs the
directory, and verifies the result. Failure before rename leaves any prior
target unchanged; failure after rename may leave either the prior file or the
complete new file, never a partial file, and reports the expected output digest
plus the error category on stderr for inspection. Consumers requiring parseable
output under delivery failure must use this mode; ordinary streamed stdout
cannot make that guarantee.

No color or prompts occur in machine flows. `--help`, `--version`, and
`catalog show` require no credentials/network. Unknown flags/fields fail. Plan is
provider-non-mutating; apply is noninteractive and requires the complete digest.
`reader auth status` is strictly local-only and is not one of the six reader or
nine total catalog operations. It parses and validates config, profile,
capability, allowlists, and required environment-reference presence/nonempty
values without printing or hashing secret values; for an allowlisted
`advertisers.list`, it additionally checks local app-ID and app-secret-reference
requirements. It never constructs a transport or makes a network request and
makes no provider-authorization claim. Exit 0 means locally ready, exit 2 means
invalid config/profile, and exit 3 means a required secret reference is missing
or empty, each with stable redacted JSON. Provider authorization is verified
only by an actual cataloged reader operation. Neither binary has a generic
network `auth verify` route; writer also has no `advertisers list` or generic
read route.

## 12. Permissions and safety model

Three gates must all pass:

1. TikTok developer app has the exact official application permission.
2. The token is authorized for the advertiser.
3. The local capability profile allowlists that advertiser and operation.

Business Center Analyst/Operator/Admin is contextual human access, not a
substitute for any gate. Prefer distinct reader and writer developer apps and
tokens. If TikTok scope granularity makes the writer token broader, the writer
binary, catalog, typed request builder, profile operation list, and tests remain
the effective local least-privilege boundary.

## 13. Observability and privacy

Local structured metadata may include timestamp, invocation ID, operation,
profile ID, advertiser/resource IDs, API/catalog revision, attempt count,
duration, HTTP status, provider code/request ID, page/limit counters, plan and
observation digests, journal transition, and required action. It excludes
tokens, app secrets, authorization codes, cookies, full URLs/queries, headers,
raw bodies, names, emails, report rows, and free-form operator text.

Diagnostics expose only the fixed safe timing and state-transition fields
listed above. No telemetry leaves the machine. Request IDs and digests are
correlation data, not proof of causality.

## 14. Adjacent-feature and compatibility impacts

- `Package.swift`, Sources, and Tests will gain separate shared/reader/writer
  targets; the current target names and single executable are compatibility
  concerns for the later implementation plan.
- Homebrew formula/cask packaging and smoke scripts currently assume one
  binary and must explicitly package/test only reader and writer; the old
  unqualified product is removed and must not be installed as a shim or alias.
- README/help must describe external token provisioning, app-secret need only
  for `advertisers.list` and its ephemeral transport, local-only auth status,
  separate profiles, partial pagination, writer claims,
  valid empty results, throttle-warning partials, later-page failure envelopes,
  stdout truncation versus atomic output, no-op versus actionable plans,
  clock-invalidated plans, authoritative per-child crash recovery,
  ambiguity/reconciliation, explicit rollback selection, two-phase rollback
  acknowledgment, bounded lock contention, unsupported whole-parent restore,
  and no automatic rollback.
- Release readiness must be computed from catalog evidence; a planned row can
  be shown but never dispatched.
- Writer journals, replay tombstones, recovery profiles, capacity thresholds,
  AUTHORITY anchors, checkpoints/GC, permanent reset blocks,
  recovery-observation segments, self-contained backups, quarantine, and epoch
  rotation add private local-state, support, migration, and operator-runbook
  obligations; persistence tests must cover both supported in-band restore and
  the explicit out-of-band rollback exclusion.
- Migration implementation and fixtures must persist phase-specific resume
  eligibility, expose pending recovery through inspect, accept digest-only
  resume after output loss/handoff, and recover the source-lock-last cut without recreating it.
  Quarantine, reset, receipt export, checkpoint, backup, and archive routing
  must share the 24-probe sealed-candidate/stabilization evaluator and mandatory
  final all-root scan, while packaging must
  continue rejecting known legacy-writer co-installation. None of these
  lifecycle rules changes reader routes or TikTok request semantics.
- AUTHORITY, quarantine manifests, lifecycle results, inspection output, and
  crash recovery must share current-seal digest/sequence, predecessor chain,
  maintenanceBaseRoot, and replacement-seal semantics. Archive/checkpoint
  maintenance committed before drift must remain authoritative across re-seal
  and re-reset even when its original command output was suppressed.
- TikTok v1.3 models and permissions must not reuse Google equivalents.
- The retained older TikTok draft/evidence files can confuse future work; they
  should be consolidated only in a separately authorized documentation cleanup.

## 15. Preconditions and rollback constraints

Preconditions are a supported macOS filesystem with exclusive create, atomic
same-directory rename, file/directory fsync, owner checks, and trusted
effective-user control; an approved TikTok app/token; advertiser authorization;
stable OS boot-session identity and system-wide continuous time; and a complete
reviewed catalog. Network filesystems without those guarantees are unsupported
for writer state.

Assumptions are explicit: the effective local user and owner-only state parent
are trusted; the stated advisory-lock, exclusive-create, atomic-rename, fsync,
boot-identity, and continuous-time primitives are available; approved app
credentials and advertiser authorization are externally managed; cataloged
compatible legacy writers honor their advisory lock; the operator truthfully
retires legacy writers and establishes quiescence when a corrupt/incompatible
source cannot be locked; identical pre/post scans are meaningful only within
that trusted-effective-user boundary; TikTok offers
no compare-and-set, mutation idempotency, rejection atomicity, or causal
  readback guarantee; and the authoritative root plus this incorporated annex
  govern. Authenticated provider behavior remains an unverified assumption
until the safe smoke workflow succeeds.

There is no database migration from the scaffold. Config schema 1 and writer
state schema 1 are new. Rollback changes provider status through a new plan; it
cannot restore transient delivery, attribution, spend, learning state, or prove
that the gateway caused the state being reversed.

## 16. Verification strategy and release gates

### Documentation evidence completed

- Inspected `AGENTS.md`, Package.swift, Swift sources/tests, README, mise,
  SwiftLint configuration, and all related design/user-QA files.
- Inspected the sibling Google gateway Package.swift, architecture/safety
  designs, targets, client/auth/transport/CLI files, and tests.
- Retrieved current official TikTok help, authorization, authentication,
  endpoint, error, HTTP-status, and rate-limit pages on 2026-08-15.
- Confirmed all official URLs returned HTTP 200. The ordinary browser tool was
  unavailable; official public documentation content was retrieved through the
  site's own unauthenticated content endpoint.
- No credentials were available or requested, so no authenticated API call was
  attempted.

### Required automated verification after implementation

- Package-graph and binary-symbol/CLI tests prove reader cannot construct or
  route writer operations; cross-capability profiles fail before secrets; and
  no unqualified compatibility product, executable, wrapper, or installed alias
  exists.
- Exhaustive CLI-table tests accept every Section 11 grammar row with each
  legal shared-flag combination and reject every unlisted route, short flag,
  positional, duplicate, inapplicable flag, missing required combination,
  mutual exclusion, output alias, config-precedence violation, and lock/page
  boundary before secrets, state mutation, or network.
- Contract fixtures cover all nine endpoints, string-ID precision, headers,
  query encoding, response/application errors, page limits, deleted/default
  behavior, valid first/beyond-range/traversal empty pages, report throttle
  warnings on first/intermediate/final pages, malformed throttle headers, and
  v1.3 drift.
- Trust-input fixtures reject duplicate keys at every depth and duplicate or
  normalization-conflicting profile, advertiser, operation, and resource IDs
  before secret lookup; authorization-fingerprint fixtures prove deterministic
  ordering, reference-change invalidation, and same-reference token rotation.
- Secret-leak corpus covers raw/encoded token and app secret in URL, headers,
  provider messages, transport descriptions, tracing callbacks, stdout/stderr,
  thrown errors, plans, journals, and test failures. `advertisers.list` fixtures
  additionally snapshot application-container files, shared/local URL caches,
  cookie and credential stores, task metrics, proxy/challenge callbacks, crash
  diagnostics, and post-invalidation state, proving no secret-bearing additions
  to the bounded gateway-accessible stores. Deployment-precondition tests cover
  every proxy environment key, system proxy/PAC/auto-discovery state, custom
  proxy dictionary, supported/unsupported runtime, missing inspection API, and
  absent/present deployment attestation. Attestation fixtures cover safe-file
  checks, duplicate/unknown fields, every binding mismatch, false/missing
  assertion, bad canonical digest, future issue time, expiry, intervals over 24
  hours, executable/OS/runtime/catalog/profile/app/deployment/network changes,
  boot mismatch, reboot, continuous-clock regression/expiry, wall-clock
  rollback below CLOCK, missing/corrupt CLOCK, no cross-invocation cache, and
  the closed safe failure reasons. Unsupported,
  stale, unrelated, or ambiguous cases must
  keep the operation disabled before secret resolution. Tests make no claim
  about uninspectable external infrastructure.
- Pagination property/fuzz tests cover loops, regressions, inconsistent totals,
  duplicates, depth/string/container/byte/item/memory limits, cancellation,
  later-page auth/throttle/permanent/transient/transport/protocol failures,
  retained-prefix guarantees, valid versus anomalous empty pages,
  exit/action/stderr behavior, stdout truncation on injected write failure,
  atomic output-file preservation, and proof that final output creates no
  second complete buffer.
- Writer tests cover every crash/fsync cut point, concurrent applies,
  apply-versus-rollback/reconcile/lifecycle operations, crash-released lock
  ownership, exact generation snapshots, stale/modified/old-epoch plans,
  one-shot transport, redirects/challenges/connection loss, no retry, provider
  rejection, unknown/partial effects, and mandatory fair readback. Crash tests
  kill before/after each claim, active-child, outcome, observation, and receipt
  CURRENT commit and prove startup never dispatches a claimed child.
- Canonicalization fixtures span separate processes and verify RFC 8785 bytes,
  domain-separated SHA-256, duplicate-key rejection at every depth, NFC,
  timestamp format, integer-only numeric fields, and deterministic child order.
- Exhaustive writer result tests enumerate dispatch evidence, provider outcome,
  child kind/state, observation, durability, output delivery, auth, and throttle
  combinations; prove every legal tuple has exactly one exit/action; and prove
  every invalid tuple enters writer-wide `storageIntegrityUnknown`. A dedicated
  proven-unsent fixture matches only predicate 3 and maps exactly to
  exit 8/`newPlan`. End-to-end fixtures cover every provider-outcome/usable-
  observation ambiguity row, prove none can create a rollback manifest, require
  exact plan/observation digests for `ambiguity-close`, install permanent
  denial tombstones for exactly the affected resources, preserve all unrelated
  blocks, allow unrelated resources only after no other global block remains,
  reject affected resources across checkpoint/archive/restore/epoch rotation,
  and prove missing/corrupt/unreadable evidence can never use the close path.
  Dedicated cases prove every rejection-plus-allPrior first observation remains
  blocked for one bounded reconciliation, no follow-up mutation can start in
  that interval, and a repeated allPrior observation transitions to
  `ambiguityPending` rather than exit 4 or rollback eligibility.
  Sequence fixtures start with any number of missing/unreadable attempts, then
  a first usable all-prior result, and prove closure remains forbidden until a
  strictly later usable all-prior attempt confirms it. Schema-union tests cover
  every apply, rollback, lifecycle, and utility command; required/forbidden
  identity fields; every allowed action subset; and rejection of cross-workflow
  fields or actions.
- Recovery tests remove/replace profiles and credentials, revoke authorization,
  disable mutation operations, retire catalog revisions, migrate a proven
  equivalent recovery descriptor, and verify deterministic reauthorize,
  reconcile, quarantine, permanently blocked reset, or manual-inspection
  behavior. Backup tests prove self-containment, exact AUTHORITY matching,
  latest-root recovery, and rejection of older valid backups after later claims.
  Threat-boundary tests model CURRENT and AUTHORITY rollback together, prove it
  is locally indistinguishable rather than claiming detection, then exercise
  the operator-reported permanently disabling reset path and runbook.
- Production-root fixtures derive the effective-user account-record path,
  reject `HOME`/config/CLI/bundle/version overrides, symlinks, alternate inode
  chains, and unsafe ownership/modes; assert the exact
  `canonicalStateParent`, lock, CURRENT, AUTHORITY, epoch, backup, quarantine,
  and migration paths across both executables and version changes; issue
  exactly the 24 descriptor probes formed by `legacyStateRoots.v1` and
  `legacyEvidenceMarkers.v2`; test each of eight marker names at each of three
  roots, including migrations-only, missing-lock INTENT, corrupt INTENT, and
  unreadable INTENT cases; ignore roots with none of the eight markers; reject
  marker types and canonical inode aliases; perform no recursive or
  unlisted-path discovery; and prove every writer command shares the one
  canonical lock and AUTHORITY. The test-only injected parent/catalog cannot be
  enabled in production builds.
- Legacy-recovery fixtures prove the lock is acquired before discovery; every
  command outside the base recovery allowlist or eligible post-reset maintenance
  set rejects detected evidence before secrets/network; inspect remains
  reachable and classifies source stability. Quarantine fixtures acquire all
  compatible locks in canonical/root-ID order, reject busy locks, require the
  quiescence acknowledgment only for incompatible/unreadable locks, recompute
  the input digest after stabilization, copy through opened descriptors, and
  require an identical post-copy scan before sealing. Mutation between every
  scan/copy/seal cut fails closed without a coherent-snapshot claim.
- Reset fixtures preserve legacy sources, create permanently blocked authority,
  and permit exactly `postResetMaintenanceCommands.v1` while every candidate
  matches the seal. Every maintenance command performs a final 24-probe all-root
  scan after its last canonical commit and before result/output publication,
  including when all original candidates remain compatibly locked. Candidate
  addition in a previously empty root, removal, replacement, mode/digest drift,
  lock contention, or changed quiescence evidence suppresses output and rejects later maintenance;
  plan/apply/reconcile/rollback/restore/initialize/migrate/rotation and all
  network dispatch remain unavailable.
- Post-reset drift-recovery fixtures inspect the drift, reject every quarantine
  reason except `post-reset-candidate-drift`, stabilize the replacement
  candidate set, and verify predecessor seal, incremented sequence, seal-chain
  root, latest maintenanceBaseRoot, and direct transition from
  `permanentlyBlockedUnknownPriorState` to
  `permanentlyBlockedQuarantined`. Crash fixtures cover before/after staging,
  seal publication, CURRENT commit, and AUTHORITY advance; exact retries reuse
  matching stages/receipts, while conflicting stages or further drift require a
  new inspection. Output-loss/cold-handoff inspection exposes the current seal,
  sequence, and maintenance base without free text. Re-reset fixtures reject predecessor seals, carry every
  committed maintenance change and the full seal chain into the next blocked
  epoch, crash on both sides of the epoch switch, and prove maintenance becomes
  reachable only after exact replacement-seal match. Repeated cycles never
  enable any mutation or network recovery command.
- Migration fixtures cover each cataloged root, fresh start with absent
  canonical authority, byte-preservation of AUTHORITY, CURRENT, claims, replay
  indexes, tombstones, blocks, observations, modes, and high-water, and all five
  phase predicates. Crash fixtures stop before/after INTENT, activation, every
  retirement batch, last-lock unlink, phase receipt, and completion receipt.
  Resume before lock retirement reacquires only the bound lock; the exact
  last-unlink crash cut advances without recreating it; post-retirement resume
  accepts only the INTENT-bound canonical target plus zero legacy evidence.
  Any other authority, source reappearance, extra candidate, phase conflict,
  stale arguments, or drift is quarantine-only. Zero-root, multi-root,
  canonical-plus-legacy fresh start, corrupt/unknown-schema, alias, and
  uncataloged-root cases reject without mutation authority.
  At every nonterminal phase, crash/output-loss/cold-handoff fixtures run
  `state inspect`, require the exact closed pending-migration tuple, resume with
  only its migration digest plus acknowledgment, and recover or return the
  existing receipt without reconstructing lost fresh-start arguments. Multiple,
  corrupt, or unreadable INTENTs never emit a resumable tuple.
  Lock fixtures hold the compatible legacy lock from a separate process, prove
  migration times out without staging, and prove canonical-then-source ordering
  under cancellation. Packaging/smoke fixtures reject a co-installed known
  legacy writer and require the retirement acknowledgment; documentation states
  that an unknown manually copied legacy executable cannot be excluded locally.
- Capacity tests cover child/file/deadline limits, pre-child cutoff, 70/80/95%
  thresholds, emergency reserve, disk-full at each commit point, tombstone
  compaction, inline observation-limit recovery archival, reconciliation above
  95%, archive corruption/failure, clean epoch rotation, and replay rejection
  after compaction/rotation. Checkpoint/GC tests crash before/after CURRENT and
  AUTHORITY advance and during deletion, verify physical-byte accounting, and
  prove startup needs only the latest checkpoint-to-CURRENT chain.
- No-op tests prove all-no-op plan/apply creates a durable claim/receipt with
  zero mutation-request construction or transport calls; mixed classifications
  fail without a plan; and final-preflight classification change consumes no
  plan. Rollback fixtures cover manifest hashing/expiry, acknowledgment drift,
  explicit selection/default rejection/duplicates/order/authorization,
  non-network rollback inspection/planning with zero credential or transport
  construction, all-actionable manifests, rejection of no-op/mixed manifest
  fields, final-preflight target-already-present staleness, and networked resume
  exclusion of externally satisfied untouched children,
  authoritative per-child crash cuts, cancellation, reconciliation, non-
  dispatching resume output, two-phase reconcile/acknowledge terminalization,
  repeated reads, stale and idempotent acknowledgments, and fresh-manifest
  execution. Every non-clean first usable observation, including every
  rejection class plus all-prior, must remain blocked through a later bounded
  rollback reconciliation; acknowledgment of persistent rejection/prior,
  unknown, contradictory, or mixed results must
  require the exact observation digest and literal risk flag and install
  permanent affected-resource denial tombstones. Only accepted/desired terminal
  children avoid denial. Digest-as-risk and flag-as-digest substitutions fail.
- Quarantine/reset fixtures require the literal permanent-disable acknowledgment
  at entry, reject structural-corruption without a closed inspection evidence
  class, prove no restore/unquarantine/re-enable transition exists, and cover
  healthy suspected-rollback and corrupt-state reasons, inspection drift,
  schema/member/seal digests, every block/copy/
  rename/CURRENT/AUTHORITY crash cut, idempotent retry, conflicting staging,
  reset predecessor binding, and permanent mutation denial. Archive fixtures
  prove plan non-mutation, snapshot/digest/expiry checks, archive reuse before
  compaction, every publication/authority/GC crash cut, idempotent receipt, and
  that active or ambiguous records are never selected or deleted.
- Clock fixtures use independent processes and injected boot/wall/continuous
  providers to cover normal expiry, reboot, backward/forward wall jumps,
  continuous regression, durable high-water advancement, and refusal to lower
  the high-water. Output fixtures inject short writes, EPIPE, cancellation,
  fsync/rename/directory-fsync failures, and post-claim delivery failure.
- Local real-server tests prove exactly one mutation body reaches the server
  across redirect, authentication challenge, body-stream replay request,
  connection loss, and connectivity recovery scenarios.
- Coordination tests cover zero/default/maximum lock deadlines, cancellation
  before acquisition, live and suspended holders, OS release after crash, and
  rapidly restarting contenders. Injected-clock writer fixtures require an
  exact two-second cancellation-finalization start deadline and verify no work
  starts after it, the last verified CURRENT result when idle, late success and
  failure of every injected blocking durability syscall, lock retention, crash
  interpretation, matching reserve arithmetic, and clipped absolute deadline.
  A table-driven suite executes every row in the command cancellation matrix at
  pre-lock, pre-cut, entered-syscall, post-cut/pre-output, and output cut points;
  it proves no work starts after the deadline and exact retries are idempotent.
  Reader auth-status
  tests prove no transport is constructed, the fixed catalog count remains
  nine, and no secret value is emitted.
- Run `mise run lint`, `mise run test`, and `mise run build`; no Swift command
  is required for this documentation-only change.

### Safe authenticated smoke verification

Use only `taco-dev-sandbox@mutvar.com`, injected secrets, the sandbox advertiser
allowlist, one page, and a one-day zero/low-volume BASIC report. Never print
payloads or credentials. Reader checks precede writer checks. A writer smoke
test may submit only resources already at the requested status. Planning must
emit a uniformly no-op plan; apply must use the no-op executor, commit a durable
no-op receipt, and have no code path to construct or call mutation transport.
Any actionable or mixed classification aborts the smoke test before apply. An
actual status dispatch requires explicit later authorization and an isolated
non-serving sandbox resource.

Repeatable non-secret commands:

```text
kinko exec --env TIKTOK_SANDBOX_READER_ACCESS_TOKEN -- tiktok-business-gateway-reader auth status --profile sandbox-reader
kinko exec --env TIKTOK_SANDBOX_READER_ACCESS_TOKEN -- tiktok-business-gateway-reader advertisers get --profile sandbox-reader --advertiser-id <sandbox-advertiser-id>
kinko exec --env TIKTOK_SANDBOX_READER_ACCESS_TOKEN -- tiktok-business-gateway-reader campaigns list --profile sandbox-reader --advertiser-id <sandbox-advertiser-id> --page 1 --page-size 1
kinko exec --env TIKTOK_SANDBOX_READER_ACCESS_TOKEN -- tiktok-business-gateway-reader reports integrated --profile sandbox-reader --request-file <sanitized-one-day-request.json>
kinko exec --env TIKTOK_SANDBOX_WRITER_ACCESS_TOKEN -- tiktok-business-gateway-writer status plan --profile sandbox-writer --request-file <already-current-request.json> --output <no-op-plan.json>
kinko exec --env TIKTOK_SANDBOX_WRITER_ACCESS_TOKEN -- tiktok-business-gateway-writer status apply --plan <no-op-plan.json> --confirm-digest <sha256>
```

The first command validates only local credential injection and configuration;
`advertisers get` is the first network/provider-authorization check.

`advertisers.list` additionally needs its app-secret environment variable and
must remain disabled until the URL-leak suite passes. Do not place environment
values in command text.

### Readiness booleans

- `acceptedResultAvailable`: false
- `needsRevision`: false
- `designAuthorComplete`: true
- `knownHighOrMediumFindingsUnresolved`: false
- `independentDeepReviewPassed`: false
- `authenticatedSmokePassed`: false
- `featureProductionReady`: false
- `routeToDesignAuthorRevision`: false
- `routeToIndependentDeepReview`: true
- `routeToBroadReview`: false
- `routeToAdversarialReview`: false
- `routeToImplementationPlan`: false
- `routeToImplementation`: false
- `routeToSourceSecurityCheck`: false

The next workflow action is independent Node 2 review. Only an accepted result
with zero unresolved high/medium findings may route to the implementation-plan
completion loop.

## 17. Addressed review feedback

Prior deep-review rounds identified and the design now explicitly resolves:

| Review pass | High raised | Medium/middle raised | Unresolved after this revision |
|---|---:|---:|---:|
| Node 2 pass 1 | 4 | 6 | 0 |
| Node 2 pass 2 | 1 | 7 | 0 |
| Node 2 pass 3 | 2 | 5 | 0 |
| Node 2 pass 4 | 0 | 3 | 0 |
| Current official-source/author adversarial pass | 2 | 2 | 0 |
| Node 2 pass 5 | 2 | 6 | 0 after this author revision |
| Node 2 pass 6 | 5 | 5 | 0 after this author revision |
| Node 2 pass 7 | 2 | 6 | 0 after this author revision |
| Node 2 pass 8 | 2 | 4 | 0 after this author revision |
| Node 2 attempt 1 after consolidation | 1 | 2 | 0 after this author revision |
| Node 2 attempt 2 after consolidation | 1 | 3 | 0 after this author revision |
| Node 2 attempt 3 after consolidation | 2 | 6 | 0 after this author revision |
| Node 2 attempt 4 after consolidation | 0 | 6 | 0 after this author revision |
| Node 2 writer-state rerun | 2 | 0 | 0 after this author revision |
| Node 2 writer-state follow-up | 0 | 3 | 0 after this author revision |
| Node 2 transition-evidence follow-up | 1 | 2 | 0 after this author revision |
| Node 2 post-reset reseal follow-up | 0 | 1 | 0 after this author revision |

- high: atomic cross-process plan consumption, crash-safe pre-dispatch state,
  readback after every dispatched outcome, external-race limitations,
  observation-versus-causality confusion, overlapping plans/rollback, and
  redirect/client replay;
- medium: overstated endpoint verification, pagination consistency/resume and
  peak-memory bounds, rate-limit scope, trust-bearing file races, free-form
  audit leakage, writer auth route overreach, digest identity, fair readback,
  safety-read dependencies, expiry instant, multi-child rollback, total result
  mapping, missing/corrupt journal interpretation, durability outcomes,
  all-disabled readiness, and irrecoverable state recovery;
- current author review: added the app ID/app-secret contract and URL-leak gate
  required by `advertisers.list`; forced single-resource writer calls,
  `allow_partial_success=false`, and excluded `DELETE`, ACO, R&F, and campaign
  postback-window mutation; aligned the sample profile and secret invariant;
  and specified stop/no-resume behavior for partially completed multi-child
  apply.
- latest Node 2 review: corrected authenticated safety-read credential order;
  made one crash-releasing transaction lock cover all writer-state commands;
  defined recovery authorization across profile/credential/catalog changes;
  capped children, plan bytes, deadlines, state bytes, claims, journals, and
  observations; specified RFC 8785 domain-separated plan hashing and duplicate-
  key rejection; added a total writer exit/action matrix; and aligned the
  provisional rate decision with current official evidence.
- newest Node 2 review: made every claim/active-child/outcome/observation/
  receipt cut point a separately authoritative CURRENT generation; added
  per-child crash interpretation and a permanent no-resume rule; defined
  durable all-no-op execution and rejected mixed plans; rejected conflicting
  trust-input identities before secrets; added profile-authorization
  fingerprints; validated result-axis invariants before a complete pre/post-
  claim mapping; preserved emergency reconciliation and externalized bounded
  observations under capacity pressure; promoted the complete rollback
  manifest/execution/recovery contract; and specified every later-page failure.
- latest Node 2 review: added independent anti-rollback AUTHORITY anchoring and
  exact-latest self-contained restore; made unknown-state reset permanently
  mutation-blocking; defined self-contained checkpoints, crash-safe GC, and
  physical-byte accounting; separated valid empty results from anomalies;
  mapped report throttle warnings for every page position; required explicit
  bounded rollback selection; added durable clock-high-water, boot, and
  continuous-time expiry; and scoped JSON completeness while adding atomic
  output-file delivery.
- newest Node 2 review: required a one-operation nonpersistent ephemeral
  transport and persistent-store leak tests for `advertisers.list`; added
  two-phase rollback reconcile/acknowledge terminalization; made writer-result
  predicates disjoint for proven-unsent transport; explicitly excluded
  whole-parent restoration from the local anti-rollback guarantee; made reader
  auth status local-only and excluded it from the nine-operation catalog; and
  bounded and made cancellable every writer-lock acquisition.
- consolidation deep review: replaced unreachable ambiguous-state rollback
  with digest-bound non-network ambiguity closure and permanent affected-
  resource denial; established a topic-by-topic sole normative source for CLI,
  schemas, state, exits, rollback, restore, and reset; and replaced universal
  proxy-persistence proof with inspectable local preconditions, bounded local
  evidence, a dated deployment attestation, and an explicit external-network
  trust boundary.
- second consolidation deep review: requires bounded reconciliation before any
  rejection-plus-allPrior outcome can close as ambiguity; defines the fixed,
  versioned, scoped, expiring, runtime-bound deployment-attestation contract;
  makes two seconds the sole cancellation-finalization start deadline; and replaces the
  representative CLI list with an exhaustive grammar and incompatibility rules.
- third consolidation deep review: applies rejection ambiguity and permanent
  denial to rollback; fixes the production state root; binds attestations to
  boot/continuous time; defines cancellation at blocked durability cuts;
  separates observation digests from risk acknowledgment; specifies quarantine
  and reset transitions; makes archive two-phase; and removes the compatibility
  product.
- fourth consolidation deep review: defines cancellation for every writer and
  lifecycle command; makes quarantine irreversible and explicitly acknowledged;
  closes and separates apply, rollback, lifecycle, utility, and pre-result error
  schemas; makes rollback planning non-network and actionable-only; requires a
  later usable `allPrior` confirmation; and bounds alternate-root discovery to
  the finite catalog later superseded by the 24-probe transition-evidence set.
- writer-state rerun: defines the exact effective-user
  `canonicalStateParent` and every lock/AUTHORITY/epoch/recovery child location
  as one override-free normative resolution; acquires that canonical lock
  before legacy discovery; keeps inspect, digest-bound quarantine/reset, and
  single-lineage `migrate-legacy` reachable; and defines fail-closed split-state
  rejection plus crash-safe migration activation and retirement.
- writer-state follow-up: separates migration fresh-start and five
  INTENT-resume phase predicates, including the last source-lock retirement
  crash cut; permits only a closed non-dispatching post-reset maintenance set
  while candidates exactly match their seal; and makes quarantine acquire
  compatible source locks or require explicit quiescence plus identical
  stabilized pre/post-copy scans.
- transition-evidence follow-up: expands finite discovery to all eight
  authority/recovery/transition markers at all three roots; requires a final
  all-root seal comparison for every post-reset maintenance command regardless
  of locking method; and makes inspect expose a closed non-secret pending-
  migration tuple that resumes by confirmed migration digest after output loss
  or operator handoff.
- post-reset reseal follow-up: defines digest-bound replacement quarantine from
  permanently blocked reset authority, monotonic predecessor-linked seal
  fields in CURRENT/AUTHORITY, crash-safe/idempotent replacement publication,
  and exact-current-seal re-reset that carries every committed maintenance
  change and restores only the closed maintenance gate without re-enabling
  mutation.

Known unresolved high- or medium-severity design findings: none. Independent
acceptance is still pending and may produce new findings.

## 18. Provisional decisions

The detailed rationale and later-change path are in
`design-docs/user-qa/tiktok-business-gateway-decisions.md`. Current
provisional choices are: v1.3; manual ads and BASIC sync reports only; separate
binaries/modules; externally provisioned tokens; optional app secret only for
authorized-advertiser listing through a nonpersistent ephemeral transport with
a fixed-path, schema-v1, environment-bound, same-boot continuous-time-bounded
attestation and clock high-water;
local-only auth status; one-page default with bounded traversal; local
conservative throttling; ENABLE/DISABLE only; one-resource mutation dispatch;
at most five uniformly actionable or uniformly no-op apply children per plan,
and actionable-only rollback manifests;
non-secret profile-authorization fingerprints; authoritative per-transition
generations, independent latest-authority anchoring, and durable per-child state;
single-use claims and boot-bound issuance; one state transaction lock for every
writer-state command at one canonical effective-user Application Support root
with a two-second cancellable acquisition ceiling;
finite three-root/24-probe transition-evidence discovery; permanently blocked reset
after unknown state with seal-matched non-dispatching maintenance only;
mandatory final all-root maintenance validation; inspectable digest-confirmed
phase-specific INTENT migration resume and deterministic source-lock
retirement; predecessor-linked replacement re-quarantine/re-reset after
post-reset drift, carrying the latest committed maintenance root without
re-enabling mutation; lock-or-explicit-quiescence quarantine capture with pre/post-copy
validation; an explicit unsupported whole-parent-restore boundary; bounded
state with recovery segmentation, checkpoints, crash-safe GC, archive, and
clean epoch rotation; two-phase archive planning/compaction; sealed crash-safe,
irreversible, explicitly acknowledged quarantine; one-shot transport;
immutable noncausal observations;
explicit rollback selection/risk acknowledgment, two-phase terminalization,
and fresh-manifest recovery; non-network actionable-only rollback planning;
later-confirmed usable observations before rejection-plus-allPrior ambiguity
closure; an exact two-second command-wide cancellation-finalization bound; a
closed workflow-specific result union; one exhaustive CLI grammar;
atomic output-file delivery; no free-form writer metadata; and removal of the
unqualified compatibility product.

## 19. Residual risks

- TikTok can change v1.3 fields, enums, limits, permissions, rate tiers, or
  availability after the evidence date; two-reviewer evidence must be repeated
  on implementation/release dates.
- App approval, exact scopes, advertiser grants, regional constraints, and
  sandbox behavior are unverified without authorized credentials.
- The official authorized-advertiser GET necessarily transmits an app secret
  in its query; TLS protects it in transit, but local/runtime URL diagnostics
  remain a release-blocking leak risk until proved absent.
- No provider conditional mutation or idempotency is established. External
  callers can race the final read and POST; observation cannot prove causality.
- A process can die after dispatch but before durable outcome/readback. The
  design prevents resend and supports reconciliation but cannot recreate lost
  provider evidence.
- Writer-wide blocking favors safety over availability; one corrupt or
  ambiguous journal can pause unrelated advertisers, and irrecoverable latest
  state permanently disables mutation for that lineage.
- Page-number traversal is not snapshot-consistent and can miss/reorder data;
  strict memory/response limits can reject legitimate large pages.
- Process-local rate limits do not coordinate multiple CLI processes.
- Long-lived tokens are process-visible to the effective user when injected by
  environment; future Keychain support needs separate design.
- Capacity limits can deliberately block new plans and eventually require
  operator archive or clean epoch rotation; external archives and quarantines
  still retain private advertiser/status history under operator control.
- AUTHORITY loss/corruption prevents freshness proof and therefore prevents
  restore or dispatch even when an older backup is otherwise valid. Required
  recovery segments must remain available and private.
- A whole-parent, APFS, VM, system-image, or copied-tree rollback can restore
  CURRENT and AUTHORITY together and is locally undetectable. It is unsupported;
  known or suspected use permanently blocks the lineage unless a future design
  adds an independently monotonic external anchor.
- Copied or renamed state evidence outside `canonicalStateParent` and the finite
  `legacyStateRoots.v1` catalog is not discovered locally; operators must treat
  any known uncataloged lineage as suspected whole-parent rollback and
  permanently block mutation.
- Legacy migration can lock and retire a cataloged state tree and release
  packaging can reject known co-installations, but it cannot discover every
  manually copied old executable. Running such an executable after migration
  could recreate or mutate legacy state outside the canonical lock; the
  operator retirement acknowledgment and host software inventory are required
  trust preconditions.
- An incompatible or corrupt legacy source has no enforceable shared lock.
  Quarantine therefore depends on explicit operator quiescence and identical
  descriptor-based pre/post scans; a malicious trusted effective user can still
  create an ABA change that local hashing cannot distinguish.
- Post-reset maintenance preserves availability only while every legacy
  candidate exactly matches its quarantine seal. Benign source metadata drift
  blocks maintenance until the explicit replacement-seal/re-reset cycle
  completes; repeated drift can repeatedly delay maintenance and consume
  retained seal storage, although mutation remains permanently blocked.
- Streamed stdout can be truncated by consumer or filesystem failure; consumers
  requiring parseable delivery must use atomic `--output`.
- Historical duplicate design/evidence artifacts remain in the worktree and
  may be mistaken for current authority despite this document's precedence.
- The entire repository worktree is currently untracked, so later changed-file
  review must distinguish scaffold, historical drafts, and feature changes.

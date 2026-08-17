# TikTok Business Gateway Design

**Status:** Practical implementation and fixed operation catalog enabled;
authenticated sandbox and release verification pending

**Evidence checked:** 2026-08-16

**Target:** Swift 6, macOS 14+, Swift Package Manager

## Implementation reconciliation (2026-08-16)

The implemented scope intentionally narrows the earlier design at the user's
direction. The current package ships direct, explicitly confirmed,
single-resource `ENABLE`/`DISABLE` writer calls and does not implement plan,
claim, journal, reconciliation, rollback, quarantine, archive, restore, reset,
or epoch state. All sections that require those durable facilities are retained
as research for a possible later project and are non-normative for the current
code. The practical source contract is the fixed nine-operation enabled catalog,
separate reader/writer targets, profile allowlists, environment-only secrets,
bounded no-redirect HTTPS transport, typed envelopes/models/pagination, safe-
read retry policy, and one-resource writer request schemas with a mandatory
`MANUAL` resource-family assertion documented in the README and
`impl-plans/tiktok-business-gateway.md`. All nine operations are enabled from
the reviewed official endpoint matrix and locally verified synthetic contract
fixtures. Approved-app entitlement and authenticated sandbox verification
remain separate release checks.

This implementation narrowing does not claim conditional mutation,
idempotency, atomic rejection, mutation causality, approved-app entitlement, or
authenticated sandbox verification. Those remain explicit release risks.

The current normative contract is limited to this reconciliation section,
`README.md`, `impl-plans/tiktok-business-gateway.md`, the evidence manifest,
and executable code/tests. The remainder of this document and all of
`design-docs/tiktok-business-gateway.md` are historical research only. In
particular, every plan/apply lifecycle, claim, journal, reconciliation,
rollback, quarantine, archive, restore, reset, epoch, retention, cancellation,
and durable-state command or acceptance requirement below is non-normative and
must not be inferred as current behavior. No later section or annex can
override this paragraph, enable an operation, or expand the current CLI.

## 1. Purpose

`tiktok-business-gateway` is a local command-line gateway for bounded TikTok
Marketing API ad-account reads and carefully controlled ad-status mutations. It
preserves TikTok's advertiser, campaign, ad group, ad, report, permission,
pagination, version, and error semantics instead of presenting a generic HTTP
proxy.

The first implementation slice provides separate reader and writer clients in
the shared core and separate reader and writer executables. The reader lists
authorized advertisers, reads advertiser/campaign/ad-group/ad data, and runs
bounded synchronous reports. The writer only plans and applies explicit
campaign, ad-group, or ad status changes. Creation, budget/bid changes, creative
upload, audience handling, events, billing, Business Center administration,
and other mutations require separate evidence and design review.

## 2. Repository baseline and related design

The repository currently has one minimal `AppCore` library, one `AppCLI`
executable, `AppCoreTests`, and `--help`/`--version` behavior. It has no TikTok
transport, authentication, configuration, or domain model yet. The related
`google-marketing-gateway` repository establishes conventions worth retaining:

- capability-separated reader and writer executables over one shared core;
- explicit operation catalogs instead of arbitrary paths;
- profile-based credential and account allowlists;
- validation and authorization before credential resolution;
- injectable transports, clocks, sleepers, and randomness;
- JSON on stdout, structured redacted errors on stderr, and stable exit codes;
- plan/apply workflows with precondition checks for mutations.

| Reference-gateway convention | TikTok disposition | Reason for difference |
|---|---|---|
| Shared core plus reader and writer executables | Retain, split network-capable reader and writer cores, and remove the unqualified compatibility executable in slice one | The reader artifact must be unable to link mutation request builders, and exhaustive CLI behavior requires a closed product set. |
| Fixed operation catalog and profile allowlists | Retain | Both gateways must reject arbitrary URLs, headers, methods, and unlisted accounts. |
| Installed OAuth and durable credential profiles | Do not copy in slice one | TikTok requires a public callback and Marketing API-specific app-secret/code exchange; tokens stay externally provisioned. |
| GraphQL business surface and file materialization | Do not copy | This gateway uses typed JSON CLI commands and bounded page envelopes to preserve TikTok semantics. |
| Injected transport, clock, sleeper, and randomness | Retain | Deterministic retry, expiry, crash, and redaction tests require these seams. |
| Plan/apply mutation flow | Retain and harden | TikTok status endpoints have no evidenced conditional mutation or idempotency, so single-use claims, one-shot dispatch, and noncausal readback are mandatory. |
| Stable JSON output and exit codes | Retain | Automation needs deterministic outcomes without provider payload leakage. |

This design intentionally does not create an implementation plan or modify
`Package.swift`, `Sources`, `Tests`, `README.md`, or release automation.

## 3. Goals

- Provide a useful, least-privilege TikTok Marketing API v1.3 ads reader.
- Define a distinct writer client with a narrow, reviewable status-mutation
  allowlist and no arbitrary endpoint access.
- Keep API version, advertiser selection, credential selection, permissions,
  pagination, retry decisions, and provider errors explicit.
- Prevent accidental writes through separate executables, plan/apply, drift
  checks, short plan expiry, post-write verification, and fail-closed defaults.
- Preserve TikTok identifiers as strings and provider payloads without lossy
  cross-provider normalization.
- Keep access tokens, application secrets, authorization codes, and private ad
  data out of source, configuration, process arguments, logs, plans, fixtures,
  and documentation.
- Make non-network and optional sandbox verification deterministic and
  implementation-ready.

## 4. Non-goals

- A hosted service, daemon, web UI, GraphQL server, or multi-tenant credential
  broker.
- A generic REST proxy or caller-controlled URL, method, headers, API version,
  permission name, or authorization header.
- Campaign/ad-group/ad creation or general update in the first slice.
- Budget, bid, schedule, targeting, identity, creative, audience, pixel/events,
  catalog, Business Center, billing, payment, member, or permission mutations.
- Async reports, webhooks, media upload/download, Smart+, GMV Max, Reach &
  Frequency, Spark Ads, lead data, comments, or Organic API in the first slice.
- Automatically exchanging or refreshing Marketing API credentials in the
  first slice. Authorization remains an explicit operator-managed lifecycle.
- Treating the non-secret identity `taco-dev-sandbox@mutvar.com` as a token,
  credential, authorization, or permission grant.
- Implementation, implementation planning, security remediation, committing,
  or modifying unrelated work during this design step.

## 5. Acceptance criteria

Framework-design acceptance and feature production readiness are separate
gates. This design is accepted only when all of the following are true:

1. Every proposed operation is fail-closed by default; an enabled operation
   maps to a current official TikTok v1.3 endpoint and application permission.
2. Separate reader and writer client modules and executables make a reader-only
   deployment incapable of linking or dispatching a mutation.
3. Authentication, configuration, identifier handling, pagination, errors,
   rate limits, retries, API versioning, CLI output, observability, tests,
   secrets, lifecycle, rollback, and compatibility are explicit.
4. Writer operations require a current single-use, complete-plan digest, an
   owner-wide mutation lock, immediate best-effort drift read, paired durable
   pre-dispatch journal, one-shot no-redirect/no-replay transport, and fair
   bounded per-resource readback after every dispatched outcome. Provider
   outcome and observed state are reported independently; without an officially
   evidenced provider conditional mutation, neither proves gateway causality or
   an atomic unchanged-precondition guard.
5. Validation and authorization occur before any secret is resolved or network
   request is sent.
6. No secret value appears in design, source, tests, fixtures, output, logs,
   plans, claims, journals, receipts, rollback manifests, epoch records,
   inspections, backups, or quarantine; live tests use injected secrets and
   redact all failures.
7. Numeric provider limits, page-size maxima, retryable application codes, and
   exact mutation enums are implemented only after reconfirmation from the
   official endpoint pages available to the approved developer app.
8. Deep, broad, adversarial, and consistency reviews leave no unresolved high-
   or medium-severity findings.

An all-disabled catalog can satisfy framework-design acceptance but is not a
delivered gateway feature. Feature production readiness requires all nine
slice-one operations in Section 6.1 to be evidence-complete and enabled:
`advertisers.list`, `advertisers.get`, `campaigns.list`, `adgroups.list`,
`ads.list`, `reports.integrated`, and the three corresponding status-update
writers. Each must pass official-contract review, independent review, fixtures,
contract tests, approved-app permission checks, and the sandbox verification in
Section 15.2. Reader-only or resource-specific staged releases must be labeled
partial previews and cannot claim this feature delivered.

## 6. Official evidence and uncertainty register

Only official TikTok sources are authoritative for provider facts. Links were
checked without credentials on 2026-08-16. The portal is a dynamic shell, so
endpoint facts remain release-gated by a dated two-reviewer evidence snapshot.

| Official source | Evidence used |
|---|---|
| [About API for Business](https://ads.tiktok.com/help/article/marketing-api?lang=en&redirected=1) | Marketing API can query, create, and manage Ads Manager data and supports customized reports. |
| [API reference](https://business-api.tiktok.com/portal/docs/api-reference/v1.3) | Non-MCP base URL is `https://business-api.tiktok.com/open_api`; the public catalog is v1.3; endpoint names and permission labels are versioned. |
| [Marketing API authorization](https://business-api.tiktok.com/portal/docs/marketing-api-authorization/v1.3) | App ID/secret, callback, state, scope, one-use authorization code, access-token concepts, and Marketing API authorization URL. |
| [Long-term access token](https://business-api.tiktok.com/portal/docs/obtain-a-long-term-access-token/v1.3) | Long-term Marketing API tokens result from app ID/secret plus authorization code, do not expire, and can be revoked; they remain bearer secrets. |
| [Authentication API reference](https://business-api.tiktok.com/portal/docs/authentication/v1.3) | The v1.3 authentication family is distinct from ordinary ads operations. |
| [Return codes](https://business-api.tiktok.com/portal/docs/return-codes-appendix/v1.3) | HTTP 200 is not sufficient for success; the application code must also be inspected. Documented throttle codes include 40016, 40100, and 40133. |
| [HTTP status codes](https://business-api.tiktok.com/portal/docs/http-status-codes/v1.3) | HTTP and application outcomes are independent inputs to the gateway error model. |
| [Rate limits](https://business-api.tiktok.com/portal/docs/rate-limits/v1.3) | Public Basic-tier defaults are 10 QPS, 600 QPM, and 864,000 QPD, with endpoint- and approved-app-specific limits; QPM/QPD recovery windows are provider-controlled. |
| [Synchronous and asynchronous reports](https://business-api.tiktok.com/portal/docs/synchronous-and-asynchronous-reports/v1.3) | Reporting mode, dimensions, metrics, pagination, attribution, and freshness are version-sensitive; slice one selects BASIC synchronous reporting only. |
| [Business Center permissions](https://ads.tiktok.com/help/article/about-assets-and-asset-level-permissions?redirected=2) | Analyst can view ads and reports; Operator/Admin can edit ads. Human role, developer-app permission, advertiser grant, and local profile authorization are separate gates. |

### 6.1 Enabled initial endpoint matrix

An operation absent from this table is denied even if the token or TikTok app
could call it. Every entry below is fixed and enabled. The machine-readable
evidence gate is
`design-docs/references/tiktok-marketing-api-v1.3-evidence.json`; an entry can
be enabled only when its endpoint-specific official contract is substantively
reviewed and all required manifest fields are complete. The manifest is a
version-controlled build/release input used to generate capability catalogs;
production accepts no caller-selected runtime manifest path. A writer entry
also remains disabled unless every catalog-revision-pinned safety-read
dependency is independently evidenced, enabled, contract-tested, and proven
compatible for exact resource matching and status projection.

| Gateway operation ID | v1.3 endpoint | TikTok application permission | Client | Fixed behavior | Enabled |
|---|---|---|---|---|---:|
| `advertisers.list` | [`GET /oauth2/advertiser/get/`](https://business-api.tiktok.com/portal/docs/get-authorized-ad-accounts/v1.3) | Ad Account Information: read | Reader | Requires access token, app ID, and app secret; intersects results with the profile allowlist. | Yes |
| `advertisers.get` | [`GET /advertiser/info/`](https://business-api.tiktok.com/portal/docs/get-ad-account-details/v1.3) | Ad Account Information: read | Reader | Exactly one allowlisted advertiser and an allowlisted field set. | Yes |
| `campaigns.list` | [`GET /campaign/get/`](https://business-api.tiktok.com/portal/docs/get-campaigns/v1.3) | Campaign: read | Reader | Manual campaigns only; ID filter at most 100; page size 1...1000. | Yes |
| `adgroups.list` | [`GET /adgroup/get/`](https://business-api.tiktok.com/portal/docs/get-ad-groups/v1.3) | Ad Group: read | Reader | Manual non-Reach-and-Frequency groups only; ID filter at most 100; page size 1...1000 where applicable. | Yes |
| `ads.list` | [`GET /ad/get/`](https://business-api.tiktok.com/portal/docs/get-ads/v1.3) | Ad: read | Reader | Manual `ad_ids` only; ID filter at most 100; page size 1...1000. | Yes |
| `reports.integrated` | [`GET /report/integrated/get/`](https://business-api.tiktok.com/portal/docs/run-a-synchronous-report/v1.3) | Consolidated Report | Reader | BASIC synchronous report, one advertiser, allowlisted dimensions/metrics, page size 1...1000. | Yes |
| `campaigns.status.update` | [`POST /campaign/status/update/`](https://business-api.tiktok.com/portal/docs/update-the-operation-statuses-of-campaigns/v1.3) | Campaign: create/update | Writer | One manual campaign; only `ENABLE`/`DISABLE`; omit `postback_window_mode`. | Yes |
| `adgroups.status.update` | [`POST /adgroup/status/update/`](https://business-api.tiktok.com/portal/docs/update-the-statuses-of-ad-groups/v1.3) | Ad Group: create/update | Writer | One manual non-Reach-and-Frequency group; only `ENABLE`/`DISABLE`; force `allow_partial_success=false`. | Yes |
| `ads.status.update` | [`POST /ad/status/update/`](https://business-api.tiktok.com/portal/docs/update-the-statuses-of-ads/v1.3) | Ad: create/update | Writer | One manual `ad_id`; only `ENABLE`/`DISABLE`; reject `aco_ad_ids`. | Yes |

TikTok documents 1...20 identifiers for each status request and a `DELETE`
operation, but this gateway deliberately sends one identifier and rejects
`DELETE`. Schema-v5 records the direct operation fields, response projections,
local bounds, retry policy, official source, synthetic fixture provenance, and
contract tests. Durable plan, safety-read, readback, reconciliation, rollback,
and lifecycle requirements are outside this implementation and are not
enablement gates. Approved-app entitlement and authenticated sandbox checks
remain release gates.

### 6.2 Explicit uncertainties

- The public Basic-tier limits are documented, but the approved app tier and
  endpoint/advertiser limits are not proven by public pages. The gateway treats
  10 QPS, 600 QPM, and 864,000 QPD as research evidence, not entitlement.
- TikTok permissions are approved per developer app and advertiser access is
  separately granted. Documentation of an endpoint does not prove the target
  app or sandbox has permission.
- Report dimensions, metrics, combinations, latency, attribution semantics,
  and page limits change independently of the top-level API version.
- TikTok v1.3 is current in the official catalog on the evidence date, but its
  retirement timeline and a future successor can change.
- The official source describes both Marketing API long-term tokens and other
  API families' short-term/refresh tokens. Slice one deliberately supports only
  externally provisioned Marketing API long-term tokens and must not mix token
  families.
- No official evidence reviewed here establishes compare-and-set, ETag,
  version-token, or other conditional status mutation. The writer cannot close
  the race between its final read and provider dispatch unless the per-operation
  evidence manifest later proves such a facility.
- No official evidence reviewed here establishes that a nonzero application
  code or HTTP rejection makes a dispatched batch atomic. The writer therefore
  reads back every resource after every dispatched attempt.

### 6.3 Design assumptions

- All nine fixed operations are enabled under the schema-v5 direct-gateway
  evidence contract; authenticated entitlement remains a release check.
- The effective local user is trusted; hostile owner-level modification of a
  plan plus its confirmation input is outside the slice-one threat model.
- Provider conditional mutation, rejection atomicity, snapshot isolation, and
  mutation causality are absent unless endpoint-specific official evidence
  later proves them.
- CLI processes can run concurrently and may terminate at any lifecycle cut
  point; durable state and process-local limits are designed accordingly.
- Writer state uses a local filesystem that honors exclusive create, atomic
  same-directory rename, descriptor/directory fsync, and trusted-owner non-
  interference; missing/corrupt post-claim evidence still fails closed.
- No redirect, challenge, connectivity recovery, or client-library behavior is
  assumed safe for mutation replay; the one-shot transport contract and real-
  server tests must prove the configured adapter behavior.
- Final reader output uses tested segmented no-copy assembly; no second complete
  document may coexist with retained encoded segments under schema v4 limits.
- A valid `CURRENT` epoch root is the writer replay-authority boundary. Exact
  backup restoration requires identical epoch/generation/root digest; otherwise
  resumption requires sealed quarantine and explicit new-epoch reset.
- Endpoint enums, limits, permissions, response fields, and retryable codes are
  implementation-time evidence gates, not facts inferred by this design.

## 7. Capability boundaries and architecture

**Non-normative historical rationale:** Annex Section 5 is the sole contract.

### 7.1 Products and modules

The generic scaffold is split only as far as the capability boundary requires:

| Target/product | Dependency | Allowed client construction | Network capability |
|---|---|---|---|
| `TikTokBusinessGatewayShared` library | Foundation only | None | Config, errors, redaction, catalog metadata, transport protocol/value types; no concrete endpoint dispatch. |
| `TikTokBusinessGatewayReaderCore` library | Shared | `TikTokAdsReaderClient` | Six reader operations in the matrix. |
| `TikTokBusinessGatewayWriterCore` library | Shared + ReaderCore | `TikTokAdsWriterClient`; injected reader for safety checks | Three status mutations plus catalog-declared pre/post reads. |
| `tiktok-business-gateway-reader` executable | Shared + ReaderCore | Reader only | Reader commands only; no WriterCore dependency. |
| `tiktok-business-gateway-writer` executable | Shared + ReaderCore + WriterCore | Reader safety checks and writer | Plan/apply/rollback commands only. |

Tests mirror these boundaries. A package-structure test inspects the SwiftPM
dependency graph so the reader target cannot gain a WriterCore dependency by
accident. The split is a justified exception to the preference for existing
target boundaries because a single core containing concrete writer routes
would make the claimed reader-only deployment boundary false.

There is no legacy arbitrary-operation mode. The existing unqualified
`tiktok-business-gateway` product is removed in slice one. No compatibility
shim, alias, wrapper, or deprecation route is shipped; only the reader and
writer products in the normative annex have command grammars.

Core responsibilities are assigned to capability modules:

- `TikTokAdsReaderClient`: typed read methods only in ReaderCore.
- `TikTokAdsWriterClient`: typed status mutation methods only in WriterCore.
- Shared defines the transport protocol and safe request/response value types;
  ReaderCore owns the injected same-origin `URLSession` adapter with host, TLS,
  timeout, redirect, response-size, and redaction policy. WriterCore can use it
  only through ReaderCore or its own fixed writer catalog.
- ReaderCore and WriterCore own immutable capability-specific v1.3 catalog
  entries for method/path/permission/query/body/pagination/retry metadata;
  Shared owns only non-dispatching catalog value types.
- `CredentialProfileStore` and `CredentialResolver`: parse non-secret config,
  validate capability/account/operation, then resolve the token.
- `WriterPlanService`: plan canonicalization, digest, expiry, drift checks,
  dispatch, readback, receipt, and rollback-plan generation in WriterCore.
- `ApplyJournalStore`: descriptor-validated, owner-only durable claims and
  hash-chained transitions plus the stable writer-wide mutation lock under the
  fixed local state directory; it is the replay, overlap-coordination,
  integrity-gating, and crash-recovery authority for WriterCore.
- Each executable owns a strict capability-specific command/flag parser and
  stable JSON envelopes; there is no shared parser that registers writer routes
  in the reader.

No API accepts raw paths, URLs, HTTP methods, headers, arbitrary JSON bodies,
or unknown fields. `URLComponents` builds queries, including JSON-encoded list
filters exactly as required by the reviewed endpoint contract. Reader and
writer transports reject every redirect before following it, including same-
origin redirects, so credentials cannot leak and mutation bodies cannot be
replayed through redirect handling.

`WriterTransport` has a stricter one-shot contract than read transport. It
creates one foreground request task with a one-use body source; automatic
connectivity waiting, cache/cookie storage, credential storage, protocol-level
retry, redirect following, and client-managed request replay are disabled. The
delegate permits only ordinary platform server-trust evaluation before request
body transmission; it cancels HTTP-authentication, client-certificate, proxy,
redirect, and replacement-body challenges. If the networking runtime requests
a second body stream, a redirect, or any replay after invocation, the transport
refuses it and returns `possiblySent`/provider `unknown`. No code path creates a
second mutation task. A concrete networking adapter is acceptable only after a
real local-server contract test proves exactly one received mutation across
same-origin/cross-origin redirects, challenges, connection loss, and
connectivity changes.

### 7.2 Preconditions and invariants

- Base origin is exactly `https://business-api.tiktok.com`; production paths
  begin with `/open_api/v1.3/` and come only from the catalog.
- API version is pinned to `v1.3`; callers cannot override it.
- All TikTok IDs are non-empty decimal strings and are never decoded as JSON
  numbers or converted through floating point.
- A profile has exactly one capability (`reader` or `writer`), a non-empty
  advertiser allowlist, and an explicit user-invocable operation allowlist.
- Reader executables reject writer profiles; writer executables require writer
  profiles. A writer operation catalog entry declares its exact supporting read
  dependencies. Those reads require corresponding TikTok read permissions but
  are callable only inside plan/apply/readback, not as arbitrary writer CLI
  operations. A writer profile does not broaden beyond the listed status
  operations and their fixed read dependencies.
- Each advertiser ID in a request must be in the selected profile before token
  resolution. Authorized-advertiser responses are intersected with the local
  allowlist.
- Unknown config, request-file, plan, response-envelope, or CLI fields fail
  closed when they affect security or mutation meaning.
- Provider success requires an acceptable HTTP status and application
  `code == 0`; HTTP 200 alone is not success.
- A provider `request_id` is operational metadata, not the gateway mutation
  plan ID or proof of idempotency.
- Every TikTok redirect is rejected before follow. Writer requests additionally
  have a one-use body and no client-, challenge-, connectivity-, or catalog-
  managed replay path; any replay request becomes an ambiguous dispatched
  outcome and can never authorize resend.
- For an unmodified gateway-generated plan under the trusted-effective-user
  model, its complete canonical plan digest may be claimed exactly once across
  local processes. Plan ID is display metadata, not replay authority. A durable
  claim controls only local gateway replay; it cannot defend against a hostile
  owner editing all local artifacts or serialize Ads Manager, another machine,
  another user, or direct API callers.
- The final drift read and provider mutation are separate requests unless the
  evidence manifest proves a conditional provider control. Consequently the
  gateway detects but cannot eliminate concurrent external status changes.
- The reader cannot write files except an explicitly requested output path.
  Writer plans, claims, journals, and receipts are created with owner-only
  permissions and never contain tokens, app secrets, auth codes, free-form
  operator text, or raw headers.

## 8. Authentication, configuration, and permissions

**Non-normative historical rationale:** Annex Section 6 is the sole contract.

### 8.1 Operator-managed Marketing API authorization

Before gateway use, an operator must have an approved TikTok for Business
developer app, authorize the required app permission scopes for the intended
account, obtain a Marketing API long-term access token through TikTok's
official flow, and ensure the advertiser account has granted access. The
gateway does not treat a Business Center human role as sufficient API proof.

Slice one does not build authorization URLs, receive internet callbacks,
exchange authorization codes, store app secrets, refresh tokens, or revoke
tokens. This avoids mixing API-family token contracts and prevents a local CLI
from pretending it can safely receive TikTok's public callback. Later auth
automation needs its own reviewed design covering state, callback ownership,
secret storage, expiry, refresh/revocation, and recovery.

`auth status` performs only local profile and required environment-reference
presence checks in either executable. It constructs no transport and makes no
provider-authorization claim. Neither executable exposes generic network
`auth verify`; provider authorization is exercised only by a cataloged reader
operation or the writer's exact plan/apply/reconcile/rollback safety reads.

### 8.2 Configuration contract

Default config path is
`~/.config/tiktok-business-gateway/profiles.json`, overrideable only by
`--config <path>` or `TIKTOK_BUSINESS_GATEWAY_CONFIG`. The environment variable
contains a path, never JSON or a secret. Version-one shape:

```json
{
  "schemaVersion": 1,
  "profiles": [
    {
      "id": "sandbox-reader",
      "capability": "reader",
      "apiVersion": "v1.3",
      "accessTokenEnvironmentVariable": "TIKTOK_SANDBOX_READER_ACCESS_TOKEN",
      "appId": "example-app-id",
      "appSecretEnvironmentVariable": "TIKTOK_SANDBOX_APP_SECRET",
      "advertiserIds": ["1234567890123456789"],
      "operations": ["advertisers.list", "advertisers.get", "campaigns.list"]
    }
  ]
}
```

The example contains no real ID, token, or secret. `appId` and the app-secret
reference are optional and permitted only when `advertisers.list` is
allowlisted; both the access token and app secret are resolved only after all
non-secret validation. Profile IDs are unique restricted ASCII names.
Environment-variable names must match
`[A-Z][A-Z0-9_]{0,127}` and cannot name known ambient credential variables.
Duplicate advertiser IDs/operations, empty allowlists, unknown fields, and
unsupported versions/capabilities are rejected. The token environment value
must be non-empty and is resolved only after all non-secret validation passes.

Config files and all writer request, plan, claim, journal, receipt, rollback,
epoch, backup, inspection, and quarantine files are trust-bearing. Inputs are
opened once using no-follow semantics, then
the open descriptor is checked before reading: it must be a bounded regular
file owned by the effective user and not writable by group or others. Parsing
uses bytes read from that descriptor, never a reopened path. The fixed writer-
state directory and every parent created by the gateway must be owned by the
effective user with mode `0700`. Writer outputs use exclusive no-follow
creation with mode `0600`; durable transitions fsync the file, atomically
replace when required, and fsync the containing directory.

Reader-only report/filter request files are the deliberate exception to the
ownership rule so version-controlled team fixtures remain usable: they may be
owned by another user only when regular, non-symlink, not group/other writable,
descriptor-validated, and size-bounded. They never bypass profile, advertiser,
operation, or schema validation. Configuration and every writer input have no
such exception.

Reader and writer use separate profiles and preferably separate TikTok app
authorizations/tokens. A writer authorization must contain both the exact
status-mutation permissions and read permissions required for plan/drift/
readback. If TikTok permission granularity forces a broader writer token, the
gateway operation allowlist remains the controlling local boundary.
The non-secret test identity `taco-dev-sandbox@mutvar.com` may appear only in
documentation and manual-verification metadata, never as a credential lookup
key or authorization assumption.

### 8.3 Secret handling

- Tokens, app secrets, auth codes, cookies, signed URLs, and callback query
  values never appear in flags, config values, output, logs, errors, plans,
  fixtures, crash context, documentation examples, or shell commands.
- Tokens enter through a specifically named environment variable injected at
  execution time. Future Keychain support must be additive and separately
  tested; plaintext token files are not supported.
- The resolver registers loaded secret values with the redactor before any
  failure can render. Key-name redaction covers case-insensitive token,
  authorization, secret, cookie, code, and credential variants.
- `Access-Token` and the operation-specific app secret are attached only after
  final origin and operation checks. `advertisers.list` uses a dedicated
  one-operation ephemeral transport with no cookies, credentials, caches,
  redirects, diagnostics, metrics export, or persistence; it remains disabled
  until runtime leak tests prove that query-contained secret bytes are absent
  from all local stores and diagnostic paths. Request/response body tracing is
  unavailable.
- Tests use obvious fake values and assert that exact secrets and common
  encodings cannot appear in stdout/stderr or diagnostic descriptions.

## 9. Reader behavior, data model, and pagination

**Non-normative historical rationale:** Annex Section 7 is the sole contract.

### 9.1 Data model

Provider envelopes are represented without erasing TikTok fields:

```text
TikTokEnvelope<Data>
  code: Int
  message: String
  requestId: String?
  data: Data?

TikTokPageInfo
  page: Int
  pageSize: Int
  totalNumber: Int?
  totalPage: Int?

GatewayPage<Item>
  items: [Item]
  pageInfo: TikTokPageInfo
  endReached: Bool
  snapshotConsistency: notGuaranteed
  nextPageHint: Int?
  duplicateCount: Int
  retainedItemCount: Int
  encodedOutputBytes: Int
  limitKindReached: pageCount | itemCount | encodedBytes | none
  resumable: false
```

Typed advertiser, campaign, ad-group, and ad summaries include string IDs,
names, primary and secondary status where documented, create/modify times as
provider strings plus optional validated timestamps, and operation-specific
fields. Unknown additive response fields are ignored for typed decoding but can
be detected in fixture/schema-drift tests. Reports preserve dimensions,
metrics, string-rendered provider values, attribution metadata, requested time
zone, and page information; metric strings are not silently parsed into binary
floating point.

### 9.2 Pagination

For each enabled list or synchronous-report endpoint, the operation catalog
records its reviewed pagination fields; where TikTok v1.3 defines `page`,
`page_size`, and returned `page_info`, the client preserves those names and
semantics. Default behavior fetches one page. Callers may provide `--page` and
`--page-size` only when that operation supports them and within the exact
catalog limits. `--all-pages` requires `--max-pages 1...100` and cannot be
combined with `--page`. Slice one deliberately has no caller-selected
`--max-items`: stopping inside a page cannot be resumed exactly with page-
number pagination. Instead, every enabled paged operation must catalog positive
gateway values for `maxResponseItems`, `maxResponseBodyBytes`, `maxJSONDepth`,
`maxJSONStringBytes`, `maxJSONContainerEntries`, `maxDecodedPageBytes`,
`maxParserScratchBytes`, `maxPageEncodedBytes`, `maxTraversalItems`,
`maxTraversalEncodedBytes`, `maxDedupIndexBytes`,
`maxFinalEnvelopeOverheadBytes`, `maxOutputWriteBufferBytes`, and
`maxWorkingSetBytes`.
Provider maxima, when evidenced, remain separately labeled provider facts.

Automatic traversal is sequential per advertiser. Limits are enforced only at
page boundaries so stdout is always one complete JSON document. Before asking
for another page, the client conservatively reserves one maximum response: it
may proceed only when retained items plus `maxResponseItems` do not exceed
`maxTraversalItems`, encoded output plus `maxPageEncodedBytes` does not exceed
`maxTraversalEncodedBytes`, and the following conservative simultaneous-buffer
sum does not exceed `maxWorkingSetBytes`:

```text
retainedEncodedBytes
+ maxDedupIndexBytes
+ maxResponseBodyBytes
+ maxParserScratchBytes
+ maxDecodedPageBytes
+ maxPageEncodedBytes
+ maxFinalEnvelopeOverheadBytes
+ maxOutputWriteBufferBytes
```

Provider collection bodies use a gateway-owned incremental bounded JSON parser,
not an unconstrained whole-body object decoder. It rejects depth, decoded string
bytes, container-entry count, response items, parser scratch, and decoded-page
arena allocations before their cataloged limits are crossed. Each typed item is
validated and canonical-encoded once into bounded immutable segments. Final
assembly is mandated to be segmented no-copy: after all validation succeeds,
the writer emits a bounded prefix, the retained segments, separators, and a
bounded suffix directly to the selected output descriptor using no more than
`maxOutputWriteBufferBytes`. It must never allocate or materialize a second
complete document or concatenate retained item bytes into another buffer. The
maximum final document size is
`maxTraversalEncodedBytes + maxFinalEnvelopeOverheadBytes`, but those bytes do
not coexist as a second allocation. An implementation whose runtime cannot
prove this contract must instead add a second complete-document allocation to
the formula and lower catalog limits; it cannot enable the operation under the
segmented strategy.

The deduplication index reserves its worst-case ID
and table overhead up front and cannot grow beyond `maxDedupIndexBytes`. Every
received page independently must fit body, structural, decoded, item, and
encoded-contribution limits. Unsupported parser constructs and any allocation-
accounting uncertainty fail closed as an oversized/invalid response. Tests
instrument allocation and peak resident memory and assert that final output
creates no allocation proportional to the complete document beyond the already
retained segments.

Automatic traversal stops before the next request when any reservation would
cross a cumulative limit. It also stops when the provider
reports the final page, the requested page cap is reached, an empty or
non-advancing page appears, metadata is invalid/inconsistent, or an error
occurs. Every response validates positive page values, the requested/returned
page relationship when supplied, nonnegative totals, advancing page numbers,
and internally consistent `total_page`/`total_number`. A changed total,
regressing page count, or reordered conflicting duplicate makes the traversal
partial and inconsistent rather than complete.

Resource lists deduplicate by stable string resource ID across one invocation:
the first identical occurrence is retained and counted; a later occurrence
with conflicting selected fields stops traversal with exit 7. Reports preserve
duplicate rows unless the evidence manifest defines a stable composite key;
they never invent one. Concurrent provider collection changes can still cause
missed or reordered resources because no snapshot-isolation guarantee has been
established. Therefore `endReached: true` means only that this invocation
observed the provider's end condition; `snapshotConsistency` remains
`notGuaranteed`, and output never claims a complete point-in-time collection.

Cross-invocation resume is unsupported in slice one. A cumulative-limit stop is
a declared page-boundary partial result; it reports the exact retained item and
encoded-byte counts plus the limit kind before making another request.
`nextPageHint` states the
next request page for diagnosis only, and `resumable` is always false; manually
starting there is a new best-effort traversal with no deduplication or snapshot
continuity. Partial results use exit code 7 and explicitly report pages fetched,
items retained, encoded bytes, duplicates, inconsistency, limit/stop reason,
and the informational hint. The client does not invent provider page-size
maxima: a paged operation's caller-selectable page-size option remains disabled
until the official v1.3 maximum has been recorded in the catalog and tests. A
fixed officially documented default may be used when the endpoint does not
expose that option.

### 9.3 Integrated report requests

`reports integrated --request-file <path>` accepts a strict, versioned JSON
schema containing one advertiser ID, official report type/data level,
dimensions, metrics, start/end dates, filtering, page settings, and explicitly
supported attribution/time-zone options. Unknown fields, duplicate fields,
unsupported combinations, unbounded dates, inverted dates, and future dates
fail before credential resolution. A conservative gateway date-span cap is
recorded in the catalog and labelled as a gateway bound, not a TikTok limit.
Large or async reports remain excluded; a response-size limit aborts without
printing a partial JSON document.

## 10. Writer behavior and state model

**Non-normative historical rationale:** Annex Section 8 is the sole contract.

### 10.1 Allowed mutations

The writer only changes operation status for existing manual campaigns,
ad groups, or ads through the three cataloged status endpoints. Exact accepted
status transitions are operation-catalog data copied from current official
endpoint pages. It cannot create, delete, change budget/bid/schedule/targeting,
upload creative, alter authorization, or dispatch Smart+/GMV Max operations.

### 10.2 Request and plan

Writer request files have a strict schema: `schemaVersion`, `operation`,
`advertiserId`, sorted unique `resourceIds`, and `desiredStatus`. Slice one has
no free-form reason, comment, label, or audit-reference field; operators
correlate the generated plan ID with an external change record. `writer plan`
validates the request, profile, operation, advertiser, status transition, and
provider batch-size limit; then reads current resources and emits a plan with:

- plan schema/version, unique random plan ID, created/expiry timestamps;
- current writer `stateEpoch`, selected profile ID, API version, operation and
  advertiser ID;
- canonical sorted resource IDs, before statuses, and desired status;
- operation-catalog revision and any officially evidenced conditional tokens;
- `planDigest`, the SHA-256 of the canonical serialization of every plan field
  except `planDigest` itself, including schema, plan ID, timestamps, profile,
  state epoch, API/catalog revisions, operation, advertiser, resource IDs,
  before states, desired state, and conditional tokens;
- no credentials, headers, full provider payloads, or sensitive ad content.

Plans expire after ten minutes, are written with mode `0600`, and are snapshots,
not durable state or an authorization credential. `writer apply` requires
`--plan` plus an exact `--confirm-digest` value. The digest is an
accidental-change guard, not a defense against a malicious local user who can
edit both arguments and files. Replay identity is the complete `planDigest`;
plan ID is display/correlation metadata and never grants claim authority. The
single-use guarantee is therefore precisely scoped to a semantically unmodified
gateway-generated plan and cooperating gateway processes sharing the effective
user's state directory. The effective local user is trusted; authenticated plan
issuance and hostile owner-level artifact editing are outside slice one. Even an
abandoned-before-dispatch claim consumes that digest and requires a fresh plan.
`writer state initialize` must have created a current epoch before any plan is
generated. Apply rejects an absent or non-current plan epoch before credential
resolution or network access. Epoch changes therefore invalidate every existing
plan and rollback manifest even when their ordinary expiry has not elapsed.

Plan time validation uses wall and monotonic clocks. `expiresAt` must be exactly
ten minutes after `createdAt`; a plan created more than 30 seconds in the future,
an invalid interval, or wall-clock rollback greater than 30 seconds between
apply start and claim is rejected. The final authorization instant is atomic
claim publication: expiry is rechecked immediately before publication after
network preflight. A timely claim remains authorized only until a monotonic
30-second dispatch deadline. Missing that deadline before the durable
`dispatching` transition produces `abandoned-before-dispatch` and never sends.
If `dispatching` is durably recorded within the deadline, later wall-clock
expiry does not cancel the one authorized attempt. Reconciliation remains
permitted indefinitely because it never dispatches.

### 10.3 State transitions

```text
request -> validated -> planned -> apply-validating
  -> coordinated -> reserved -> dispatching -> dispatched -> observing -> observed
observed -> observing -> observed
reserved -> abandoned-before-dispatch
apply-validating -> rejected-before-claim | expired | stale | clock-invalid |
                    coordination-busy
any published claim + missing/corrupt journal -> storage-integrity-unknown
```

The journal models independent axes rather than causal terminal labels:

- dispatch evidence: `notStarted`, `possiblySent`, or `responseReceived`;
- provider outcome: `notObserved`, `accepted`, `rejected`, or `unknown`;
- latest observation: `allDesiredObserved`, `allPriorObserved`,
  `mixedObserved`, `divergentObserved`, or `incomplete`;
- immutable observation history: timestamped per-resource snapshots and their
  digest, including errors and the catalog revision used.

Each snapshot also has an `observationStateDigest` over the canonical plan
digest, catalog revision, sorted resource classifications/values, and read
errors, excluding timestamps and request IDs. It is stable only while the
semantically relevant observed state is unchanged and is the value used for
external-origin acknowledgments.

Every post-dispatch observation has `causalAttribution: unknown`. Seeing the
desired value does not prove this dispatch caused it; seeing the prior value
does not prove the desired value was never transiently applied. Provider
outcome likewise does not override observation. The journal never describes a
resource as applied or not applied by the gateway.

Plan files are immutable. The production journal root is the effective-user
account-record home resolved without `HOME`, under the literal
`Library/Application Support/tiktok-business-gateway/writer-state/v1` path;
production has no caller-controlled state-root override. The stable root contains `writer-mutation.lock`, an atomic
owner-only `CURRENT` epoch record, `epochs/<random-epoch-id>/`, and
`quarantine/`. Epoch IDs are random restricted identifiers, never timestamps or
caller input. Plans, claims, journals, receipts, and rollback manifests bind the
current epoch. Tests inject an isolated store.

All dispatch-capable writer commands share one stable owner-only
`writer-mutation.lock` inode in that directory. A nonblocking exclusive lock is
created with exclusive no-follow mode `0600`, descriptor-validated for owner,
mode, regular type, and link count, and never deleted or replaced. The lock is
acquired before final preflight and held through claim publication, the only
dispatch, mandatory first observation sweep, and durable result. Rollback-
execute/resume holds the same lock across its entire child sequence; ordinary
apply cannot interleave. This intentionally serializes distinct profiles,
advertisers, resource types, partial overlaps, and disjoint plans. Ordering is
the successful exclusive-lock acquisition order; there is no hidden queue or
fairness promise, and a loser returns `coordinationBusy`/exit 8 with
`retryLater` without consuming its plan.

While holding the writer-wide lock and before any new dispatch, the store scans
every descriptor-valid claim, journal, and rollback aggregate. Any active or
unresolved state whose deterministic required action is `reconcile`,
`reviewExternalOriginBeforeRollback`, or `manualInspection` blocks all new
dispatch. Missing/corrupt claim-journal pairs and interrupted rollback
aggregates also block. The matching recovery command acquires the same global
lock, so apply, rollback, and recovery cannot race. Complete-plan claims remain
the replay authority; the global lock is the independent overlapping-resource
coordination authority.

Durability assumes a local filesystem that honors exclusive create, atomic
same-directory rename, descriptor fsync, and directory fsync, plus no external
owner-level deletion or alteration after successful fsync. Each journal
snapshot contains the claim digest, prior-snapshot digest, schema, and state
digest. This detects accidental truncation, replacement, and broken chains but
is not authentication against the trusted owner. Once a claim is published, a
missing, mismatched, or corrupt journal is `storageIntegrityUnknown`; it never
proves dispatch did not occur, never becomes abandoned automatically, and
blocks every future mutation until Section 10.5 completes exact restoration or
an acknowledged new-epoch reset.

Apply follows this crash-safe order:

1. Descriptor-validate the config and complete plan, recalculate its digest,
   match `--confirm-digest`, validate profile/catalog revision and exact
   evidence-enabled operation, require the plan's epoch to equal healthy
   `CURRENT`, and apply the time rules above. Resolve the token only after all
   non-secret validation.
2. Acquire the writer-wide lock and run the durable-state integrity/unresolved-
   action scan above. Lock contention returns without claiming the plan; any
   unresolved or corrupt state fails closed without dispatch.
3. Re-read every resource immediately before claim. Reject before claim when a
   resource is missing or its status differs from the plan. This narrows but
   does not close the external race between read and dispatch. Recheck expiry
   and clock rollback immediately after this preflight.
4. Create unpublished random temporary claim and journal files with exclusive
   no-follow mode `0600` and acquire the temporary claim's exclusive advisory
   lock before writing. The claim contains the canonical secret-free plan,
   digest, preflight observations, and catalog metadata; the journal genesis is
   `reserved` with `dispatchEvidence: notStarted` and hashes the claim. Fsync
   both. Recheck wall expiry and rollback immediately before publication.
   Publish the journal first and the immutable `<plan-digest>.claim` last with
   no-replace same-directory renames, then fsync the directory. The claim is
   authority only after its matching valid reserved journal already exists. An
   existing digest rejects replay. Pre-claim orphan journals are not authority
   and may be cleaned only when owner-valid, unlocked, internally valid, and
   older than the documented bound.
5. Hold both writer-wide and immutable claim descriptor locks through dispatch
   and initial observation. Journal updates preserve the digest chain. Process
   death releases locks but never deletes durable artifacts.
6. Atomically create/replace and fsync the journal state `dispatching` before
   invoking the transport, then fsync the state directory. The ordering means a
   valid hash-chained `reserved` journal positively records no invocation under
   the durability assumption; absent/corrupt evidence is unknown, never safe.
7. Invoke the one-shot writer transport exactly once. Mutations are never
   automatically retried or redirected. A redirect, challenge, body-replay
   request, connection ambiguity, or transport cancellation after invocation
   is `possiblySent` regardless of whether the runtime reports bytes written.
   Persist any HTTP status, application code, cataloged safe message
   classification, and provider `request_id` as `dispatched`; raw provider
   messages/bodies and credentials are excluded. Receipt/journal persistence
   failure is `storageIntegrityUnknown` with manual recovery required, never
   permission to resend.
8. After every dispatch attempt, including HTTP or application rejection,
   timeout, cancellation, malformed response, or apparent success, read back
   every resource using the bounded fair-sweep rules below. Abrupt termination
   is recovered by reconcile.

For each enabled writer, the catalog fixes `maxMutationResources`,
`maxIdsPerRequest`, `safetyReadAttemptSeconds`, `maxFirstSweepSeconds`,
`minFirstSweepAttemptSeconds`, `maxTotalReadbackSeconds`, and
`maxCancellationFinalizeSeconds`. Validation
requires first sweep at most 30 seconds, total readback at most 120 seconds,
an exact 2-second no-new-work/start-finalization cancellation deadline, and
`ceil(maxMutationResources / maxIdsPerRequest) *
minFirstSweepAttemptSeconds <= maxFirstSweepSeconds`, with the minimum slice
positive and no greater than `safetyReadAttemptSeconds`. Readback partitions
sorted resource IDs into deterministic chunks.

The first sweep disables all safe-read retries, `Retry-After`, and backoff. It
attempts each chunk exactly once before any repeat, assigning each request the
lesser of the cataloged attempt timeout and its equal share of remaining first-
sweep time. A slow or failed chunk therefore cannot consume a later chunk's
slot. After the first sweep, later rounds rotate the starting chunk and may use
the normal safe-read retry classification, but every attempt/backoff is clipped
to the absolute monotonic `maxTotalReadbackSeconds` deadline and no attempt
starts without sufficient remaining budget.

Cancellation requested after dispatch is recorded immediately. The writer
still completes the no-retry first sweep if it is incomplete; otherwise it
cancels the active later-round read and starts no more attempts. It persists
`incomplete` plus cancellation metadata and releases coordination. Latency from
the cancellation request is bounded by the remaining first-sweep deadline, or
one active `safetyReadAttemptSeconds` after the first sweep, plus
`maxCancellationFinalizeSeconds`, always clipped to the remaining absolute
total deadline. Process termination remains a crash case handled by reconcile.
Each observation is durably classified as
`desiredObserved`, `priorObserved`, `divergentObserved`, `missing`, or
`unreadable`; the aggregate uses the observation-only values listed above.
Provider rejection never short-circuits the first sweep because batch atomicity
is unproven.

`writer status reconcile --plan-digest <sha256> --config <path>` opens the
owner-valid claim and journal for that exact digest, validates their schema and
selected profile, acquires the writer-wide and claim locks, and never dispatches.
Plan-ID lookup is optional convenience only and fails unless it resolves to one
digest. Reconcile uses the canonical snapshot inside the immutable claim, so it
does not depend on the original plan file. It is allowed after expiry and from
every post-dispatch state, including any previously observed desired, prior,
mixed, divergent, or incomplete aggregate. It repeats fair bounded readback and
appends a new immutable observation snapshot; previous observations and
provider outcome are never overwritten. A live writer causes a nonblocking
`coordinationBusy` error. A released claim with an intact hash-chained
`reserved` journal and `notStarted` dispatch evidence is durably finalized
`abandoned-before-dispatch`. Missing, mismatched, or corrupt journal evidence
becomes `storageIntegrityUnknown` and blocks dispatch; it is never finalized as
safe. Claims are never deleted or considered reusable based only on PID, age,
or timeout.

The durable journal is the canonical receipt. `writer receipt export` may
create an owner-only copy after the fact, but export failure cannot erase
recovery evidence. A completed command can report operational success only for
provider `accepted` plus `allDesiredObserved` with durable journal state; even
then causal attribution remains unknown. All contradictory, unknown,
incomplete, or nondurable combinations require reconciliation or manual review
and never authorize redispatch.

The local claim prevents duplicate dispatch by gateway processes sharing this
user-state directory. It does not serialize direct API calls, Ads Manager,
other users, other machines, or provider automation. Unless the operation's
official evidence manifest records a supported conditional/version token, no
compare-and-set value is sent and the gateway explicitly accepts that an
external change after the final read can be overwritten. If official
conditional mutation later exists, its token becomes a mandatory plan field
and stale-condition rejection still receives per-resource readback.

### 10.4 Rollback and lifecycle

There is no automatic rollback. Because observation cannot establish mutation
origin, planning and terminal acknowledgment require the exact latest
`--observation-digest <sha256>`, while planning, execution, and acknowledgment
also require the separate literal `--ack-external-origin-risk`. This confirms the
operator understands that desired-observed state might have been produced by
an external actor and rollback could reverse an unrelated external change.

`writer status rollback-plan --plan-digest <sha256> --observation-digest
<sha256> --ack-external-origin-risk --output <manifest>` opens the matching claim/journal and
performs a fresh fair read. It emits no manifest unless the resulting
`observationStateDigest` exactly matches the acknowledgment; otherwise it
reports the new digest and requires an explicit rerun. It can include only resources currently
`desiredObserved`; prior, divergent, missing, and unreadable resources are
excluded with explicit reasons. It groups included resources by recorded before
status and generates complete-digest child plans. The manifest binds the parent
plan and latest observation digests, all child fields/digests, exclusions, and
a deterministic child order by child digest; its own digest covers every field
except the manifest digest.

`writer status rollback-execute --manifest <path> --confirm-digest <sha256>
--ack-external-origin-risk` atomically creates and fsyncs
one owner-only aggregate rollback claim/journal while holding the same writer-
wide mutation lock used by ordinary apply, then retains that lock while
consuming children. Its
states are `planned`, `executing`, `stopped-before-child`,
`observation-incomplete`, `partially-executed`, and `completed`. Before each
child it durably records `nextChild`; the child then uses the ordinary complete-
digest claim, expiry, single-dispatch, and observation lifecycle. Any stale/
expired child, non-success result, or interruption stops before the next child
and persists the aggregate and every per-child result.

`writer status rollback-reconcile --manifest-digest <sha256>` may reconcile
only the active child's observations and aggregate state while holding the
writer-wide lock; it never dispatches or advances. An interrupted or unresolved
aggregate blocks ordinary apply and other rollback execution. `rollback-resume`
requires the manifest digest and an acknowledged terminal aggregate, revalidates
all remaining children, and emits a new canonical rollback manifest without
dispatch. Its later execution requires separate digest confirmation and the
literal external-origin acknowledgment. It never skips a stale child; a stale
child requires a new rollback plan based on current observations.
These durable cut points and shared coordination make interrupted multi-child
execution recoverable without racing ordinary apply or inferring whether a
child was sent. Creation and deletion have no
rollback contract because they are excluded.

### 10.5 Writer-state inspection, backup, and epoch recovery

State recovery commands acquire the writer-wide lock, use no token or network,
and never dispatch. `CURRENT` records the epoch ID, monotonically increasing
state generation, and digest of the complete authoritative claim/journal/
rollback index. Every state transaction writes and fsyncs its artifacts before
atomically advancing this root record; staged higher-generation artifacts are
detected and recovered or quarantined before dispatch. Inspection and copy read
bounded bytes from no-follow descriptors; symlinks/special files are recorded
as issue metadata and never followed or imported.

- `writer state initialize` is allowed only when no `CURRENT` or epoch exists.
  It durably creates the first random epoch and returns exit 0 plus its digest;
  partial initialization is quarantined and exits 8/`manualInspection`.
- `writer state inspect --output <path>` validates root/epoch descriptors,
  generations, complete indexes, claims, journal chains, rollback aggregates,
  orphans, and quarantine seals. It returns exit 0/`none` only when healthy.
  Any defect returns exit 8/`manualInspection` with a bounded issue list and an
  `inspectionDigest`; it makes no repair.
- `writer state backup --output <archive>` is allowed only after healthy
  inspection under the lock. It writes an owner-only complete epoch snapshot
  plus canonical manifest, generation, root digest, and per-file hashes, fsyncs
  it, and returns its backup digest. Backups contain private operational data
  but no credentials.
- `writer state restore --backup <archive> --confirm-authority-digest <sha256>` never
  overlays live files. It descriptor-validates the archive, builds and fsyncs a
  separate candidate, and permits activation only when backup epoch,
  generation, and root digest exactly equal the still-valid `CURRENT` root.
  The corrupt instance is sealed in quarantine before an atomic `CURRENT`
  switch to the bit-for-bit equivalent candidate. Any mismatch means the backup
  may omit replay authority: it is imported as recovery evidence only, remains
  dispatch-blocking, and exits 8/`manualInspection`.
- Quarantine and reset are governed solely by Annex Section 8. Quarantine binds
  an exact inspection digest and closed reason to an atomically sealed artifact
  while blocking mutation. Reset requires that seal and the literal permanent-
  disable acknowledgment and creates only a permanently mutation-blocked epoch;
  it never resumes mutations.

Reset never claims the old provider outcome is known. It is an explicit
operator acceptance that prior dispatch may have occurred and replay authority
may be incomplete. Every old-epoch plan, claim-as-input, and rollback manifest
is rejected before credential resolution, and no fresh plan may dispatch in the
permanently blocked lineage. Old epochs, corrupt originals, imported backups, and audit
manifests remain immutable and are never automatically pruned.

State command output contains command, old/new epoch IDs, generations, counts,
issue classes, artifact/inspection/backup/quarantine digests, disposition, exit,
and required action. It excludes tokens, provider bodies, ad names, and raw
resource lists. Usage/schema errors exit 2/`correctInput`; lock contention exits
8/`retryLater`; all integrity, confirmation, copy, fsync, or switch failures exit
8/`manualInspection` unless the exact successful cases above apply.

Provider state remains authoritative for ad resources, but the gateway now has
minimal durable local apply state for replay prevention and recovery. Journals
contain advertiser/resource IDs and status history, so they are private
operational data despite containing no secrets. Slice one never automatically
deletes them. A future explicit prune command must retain nonterminal journals,
require an age bound, report exact targets, and receive separate destructive-
operation review.

Config, journal, and evidence-manifest schema migration is fail-closed: a newer
schema is rejected, and any future migrator writes a new directory/file rather
than overwriting the original. A migration preserves state epoch and replay
authority; irrecoverable reset creates a new epoch and is never presented as a
migration. API-version migration requires a separate
evidence manifest and catalog, fixture/contract updates, official migration
evidence, and review; there is no automatic fallback across versions. Old
journals remain readable by their schema-specific reconciler until explicitly
retired through a reviewed migration.

## 11. Validation and error handling

**Non-normative historical rationale:** Annex Section 9 is the sole contract.

Validation order is fixed:

1. parse command and reject unknown/duplicate flags;
2. open inputs once with no-follow semantics; validate ownership, mode, regular
   type, and size on each open descriptor; read bounded bytes from that same
   descriptor;
3. validate schemas, capability, version, evidence-enabled operation, IDs,
   advertiser allowlist, permission declaration, paging/report/status bounds,
   current writer epoch, and complete plan digest;
4. resolve the token and register it for redaction;
5. build the cataloged request and enforce final origin/path/method rules;
6. for writes, acquire writer-wide coordination, scan durable integrity/action
   gates, perform the final drift read, publish paired reserved journal/claim,
   fsync `dispatching`, invoke one-shot transport once, and perform mandatory
   fair observation;
7. for reads, dispatch and decode HTTP/application envelopes and pagination.

All failures use a stable redacted JSON error:

```json
{
  "error": {
    "category": "rateLimited",
    "message": "TikTok rate limited the request",
    "operation": "campaigns.list",
    "apiVersion": "v1.3",
    "httpStatus": 429,
    "providerCode": null,
    "requestId": "redacted-example-request-id",
    "retryable": true
  }
}
```

Reader commands and writer commands outside the mutation lifecycle use this
error envelope. Mutation-lifecycle commands always use `WriterResult` below so
automation receives one deterministic state/action contract, including
pre-claim failures.

Every apply, reconcile, rollback-execute, rollback-reconcile, and rollback-
resume command returns one writer result envelope, including failures before a
claim. It exposes independent evidence axes and never infers causality:

```text
WriterResult
  workflow: apply | reconcile | rollbackExecute | rollbackReconcile |
            rollbackResume
  planId: String?
  planDigest: SHA256?
  stateEpoch: String?
  planDisposition: unclaimed | consumed | unknown
  rollbackDigest: SHA256?
  failureCategory: none | usageValidation | authenticationPermission |
                   rateLimited | preflightTransport | expiredStaleOrEpoch |
                   coordinationBusy | replayClaimed | storageIntegrity |
                   providerRejected | dispatchAmbiguous
  dispatch:
    evidence: notStarted | possiblySent | responseReceived
    attempted: Bool
  provider:
    outcome: notObserved | accepted | rejected | unknown
    httpStatus: Int?
    code: Int?
    requestId: String?
  observation:
    snapshotDigest: SHA256?
    state: none | allDesiredObserved | allPriorObserved |
           mixedObserved | divergentObserved | incomplete
    causalAttribution: unknown
    perResource: [bounded classifications]
  journal:
    durable: Bool
    state: none | reserved | dispatching | dispatched | observed |
           abandonedBeforeDispatch | storageIntegrityUnknown
    localStage: beforeTemporaryFiles | temporaryFiles | journalPublished |
                claimPublished | dispatchMarker | postDispatch
  requiredAction: none | correctInput | updateAuthorization | retryLater |
                  initializeState | inspectExistingResult | reconcile |
                  resumeRollback | newPlan |
                  reviewExternalOriginBeforeRollback | manualInspection
```

Envelope invariants make the matrix exhaustive: `notStarted` implies
`attempted: false`, provider `notObserved`, and observation `none`;
`possiblySent` implies `attempted: true` and provider `unknown`;
`responseReceived` implies `attempted: true` and provider `accepted` or
`rejected`; and any post-dispatch state without a complete fair sweep is
`incomplete`, never `none`. Schema-invalid combinations fail closed as exit 8
with `manualInspection`.

Local durability failures use the exact table below. "Remove temporary" means
close and unlink only unpublished files opened by this invocation after
descriptor/inode verification. "Quarantine" means preserve an owner-only copy
under the current epoch and make the integrity scan block dispatch. No row
authorizes transport invocation.

| Local durability predicate | Plan disposition | Cleanup/state | Exit | Required action |
|---|---|---|---:|---|
| No epoch/root/artifacts exist on a clean first use | `unclaimed` | No mutation | 8 | `initializeState` |
| Existing epoch or global-lock descriptor is missing, invalid, or unreadable | `unclaimed` | No mutation; state health unknown | 8 | `manualInspection` |
| Global lock is valid but held by another process | `unclaimed` | None | 8 | `retryLater` |
| Random temporary exclusive-create collision | `unclaimed` | Remove any file created by this invocation | 8 | `retryLater` |
| Temporary claim-lock acquisition fails | `unclaimed` | Remove verified temporary files | 8 | `manualInspection` |
| Other temporary create, write, or fsync failure before publication | `unclaimed` | Remove temporary when verified; otherwise quarantine | 8 | `manualInspection` |
| Expiry/clock recheck fails after temporary fsync but before publication | `unclaimed` | Remove verified temporary files | 8 | `newPlan` |
| Journal no-replace publication finds an existing valid claim/journal pair for this digest | `consumed` | Remove this invocation's unpublished files; return existing result | 8 | `inspectExistingResult` |
| Journal publication fails and no journal was published | `unclaimed` | Remove temporary when verified | 8 | `manualInspection` |
| Journal published but claim publication fails | `unknown` | Preserve/quarantine orphan journal; block dispatch | 8 | `manualInspection` |
| Claim rename succeeds but paired directory fsync fails or is uncertain | `unknown` | Mark/retain `storageIntegrityUnknown`; block dispatch | 8 | `manualInspection` |
| Claim pair is durable but `CURRENT` generation/root update fails or is uncertain | `consumed` | `storageIntegrityUnknown`; block dispatch | 8 | `manualInspection` |
| Dispatch-marker preparation fails while valid reserved journal remains and durable abandoned finalization succeeds | `consumed` | `abandonedBeforeDispatch`; no invocation | 8 | `newPlan` |
| Dispatch-marker rename/fsync or abandoned finalization is uncertain | `unknown` | `storageIntegrityUnknown`; block dispatch | 8 | `manualInspection` |

If cleanup itself fails, the row is promoted to quarantine plus exit 8/
`manualInspection`. The implementation records the selected predicate,
disposition, cleanup result, and artifact digests in the result/audit output;
it never retries publication or advances to dispatch after a durability error.

Rollback aggregate results add ordered bounded `childResults` using this same
schema. Rollback-plan exits 0/`none` only after its manifest is durably written;
acknowledgment mismatch is exit 8/`reviewExternalOriginBeforeRollback` with no
manifest. Aggregate execution uses the exact mapping below. When an aggregate
must propagate a child action, it selects the first present in this fixed
precedence: `manualInspection`, `reconcile`,
`reviewExternalOriginBeforeRollback`, `newPlan`, `retryLater`,
`resumeRollback`, `inspectExistingResult`, `none`.

| Rollback aggregate predicate | Exit | Required action |
|---|---:|---|
| Journal missing, corrupt, mismatched, or nondurable | 8 | `manualInspection` |
| `completed` and every child exit is 0 | 0 | `none` |
| `planned` with no child started and all children current | 8 | `resumeRollback` |
| `observation-incomplete` or active child requires reconcile | 8 | `reconcile` |
| `stopped-before-child` because a remaining child is stale/expired | 8 | `newPlan` |
| `stopped-before-child` after cancellation with current remaining children | 8 | `resumeRollback` |
| `partially-executed`, completed children exit 0, and remaining children current | 8 | `resumeRollback` |
| `partially-executed` with any nonzero child | 8 | Fixed child-action precedence above |
| Schema-invalid aggregate combination | 8 | `manualInspection` |

The writer exit contract below is exhaustive and deterministic. Preconditions
are mutually exclusive within each phase. Local durability predicates use the
preceding table before this general table; post-dispatch evaluation checks
journal integrity first, dispatch evidence second, then provider/observation:

| Phase and exact predicate | Exit | Required action |
|---|---:|---|
| Pre-claim usage, schema, digest, or configuration failure | 2 | `correctInput` |
| Pre-claim token, advertiser authorization, or permission failure | 3 | `updateAuthorization` |
| Pre-claim rate/throttle budget exhausted | 5 | `retryLater` |
| Pre-claim safety-read transport, timeout, or invalid response | 6 | `retryLater` |
| Pre-claim non-auth, non-rate provider rejection | 4 | `manualInspection` |
| Pre-claim expired, stale, old/non-current-epoch, future-time, or clock-invalid plan | 8 | `newPlan` |
| Writer-wide lock held; plan not claimed | 8 | `retryLater` |
| Existing claimed digest with a valid durable result | 8 | `inspectExistingResult` |
| Valid consumed `reserved/notStarted` plan that cannot dispatch | 8 | `newPlan` |
| Any missing, corrupt, mismatched, or nondurable post-claim state | 8 | `manualInspection` |
| `possiblySent`/provider `unknown` plus `incomplete` observation | 8 | `reconcile` |
| `possiblySent`/provider `unknown` plus any complete observation | 8 | `manualInspection` |
| Provider `accepted` plus `allDesiredObserved` | 0 | `none` |
| Provider `accepted` plus `allPriorObserved` | 8 | `reconcile` |
| Provider `accepted` plus `mixedObserved` | 8 | `reviewExternalOriginBeforeRollback` |
| Provider `accepted` plus `divergentObserved` | 8 | `manualInspection` |
| Provider `accepted` plus `incomplete` | 8 | `reconcile` |
| Provider `rejected` plus `allDesiredObserved` | 8 | `reviewExternalOriginBeforeRollback` |
| Provider `rejected` plus `allPriorObserved` | 8 | `reconcile`, then permanent-denial ambiguity closure if it persists |
| Provider `rejected` plus `mixedObserved` | 8 | `reviewExternalOriginBeforeRollback` |
| Provider `rejected` plus `divergentObserved` | 8 | `manualInspection` |
| Provider `rejected` plus `incomplete` | 8 | `reconcile` |
| Any schema-invalid axis combination | 8 | `manualInspection` |

Exit 6 applies to reads and to writer safety-read transport failure proven to
occur before claim publication/transport invocation. Once `dispatching` is
durable or invocation might have occurred, ambiguity is always exit 8 rather
than exit 6. A later reconcile may append a new observation and produce a new
result envelope but never rewrites the earlier result or provider outcome.

Categories and exit codes are:

| Exit | Category | Meaning |
|---:|---|---|
| 0 | success | Complete read success, or provider accepted plus all desired observed with durable writer state; writer causality remains unknown. |
| 2 | usage/validation/configuration | Local caller or non-secret configuration error. |
| 3 | authentication/permission | Missing token, invalid token, unauthorized advertiser, or missing app permission. |
| 4 | providerRejected | Non-retryable TikTok rejection with all prior values observed and durable writer state. |
| 5 | rateLimited/retryExhausted | Throttled or transient read exhausted its budget. |
| 6 | transport/timeout/invalidResponse | Read failure, or writer failure proven before claim/dispatch invocation. |
| 7 | partial | A bounded multi-page read returned a declared partial result. |
| 8 | expired/stale/replay/coordinationBusy/ambiguous/storageIntegrity | Writer safety precondition, consumed plan, active writer, unknown causality, contradictory outcome, or incomplete/corrupt durability state. |

HTTP status and TikTok application `code` are preserved separately. Messages
are safe summaries, never unfiltered bodies. `request_id`, when present, is
preserved for support. Unknown application codes are non-retryable until the
current official return-code table classifies them.

## 12. Rate limits, timeouts, and retries

**Non-normative historical rationale:** Annex Section 10 is the sole contract.

TikTok's public rate page documents Basic app defaults of 10 QPS, 600 QPM, and
864,000 QPD, but approved-app and endpoint-specific limits remain unknown.
Therefore:

- the operation catalog records public defaults separately from verified
  approved-app and endpoint limits and never treats the public tier as an
  entitlement;
- each CLI process imposes a conservative local safety cap of one in-flight
  read per profile and at most two request starts per second; these are
  provisional process-local gateway policy and configurable only downward in
  slice one;
- every request has connect and overall deadlines, a bounded response body,
  and cancellation propagation;
- `Retry-After` is honored when a same-origin response supplies a valid bounded
  value;
- safe reads may retry HTTP 408, 429, and 5xx with full-jitter exponential
  backoff, at most three retries and a 30-second total retry budget;
- writer first-sweep safety reads are the explicit exception: they make exactly
  one no-retry attempt per chunk, ignore `Retry-After` until later rotated
  rounds, and obey the absolute readback/cancellation deadlines in Section 10.3;
- application-level codes retry only when the versioned catalog maps the exact
  code from TikTok's current official return-code table to transient/throttled;
- validation, authentication, permission, malformed-response, and other 4xx
  failures do not retry;
- status mutations never redirect, retry, replace their one-use body, wait for
  connectivity, satisfy replay-capable challenges, or automatically resend
  after invocation. Every dispatched outcome, including rejection or ambiguity,
  uses mandatory per-resource readback as defined above.

Retries report attempt count and accumulated wait without secret/body data.
Tests use injected clocks, sleepers, and deterministic jitter. A future numeric
limit change is catalog/config work, not a source-code constant hidden in a
client. Slice one deliberately does not coordinate rate buckets across CLI
processes: concurrent processes can exceed the intended aggregate profile/app
rate and receive provider throttling. An interprocess limiter would require a
separate owner-only lock/bucket design, stale-lock recovery, and tests; it is
not implied by the writer apply journal.

## 13. CLI behavior and user-visible flows

**Non-normative historical rationale:** Annex Section 11 is the sole contract.

The user-visible intent is separate read and mutation surfaces, local-only
configuration/authentication diagnostics, bounded paged output, noninteractive
digest-confirmed mutation, non-dispatching recovery, and stable redacted JSON.
Exact command paths, flags, combinations, output requirements, and rejected
syntax are defined exhaustively only in Annex Section 11; no example or prose
in this root adds a route, alias, or option.

## 14. Observability and privacy

**Normative scope:** Only Section 14.1's threat-actor table is additive.
Annex Sections 12-13 are the sole permissions, safety, observability, and
privacy contract; the other prose in this section is historical rationale.

Default observability is local structured metadata only: timestamp, invocation
ID, executable capability, operation ID, profile ID, advertiser ID, API/catalog
version, attempt count, duration, HTTP status, provider code, provider
`request_id`, page/item/encoded-byte counts, duplicate/inconsistency counts,
plan/observation/rollback digests, claim/journal state, dispatch evidence,
provider outcome, per-resource observation class, global coordination state,
state epoch/generation, storage-integrity and recovery-command status,
inspection/backup/quarantine digests, rejected redirect/replay event class,
catalog readiness, and required operator action. Logs always mark writer causal
attribution `unknown`.
Ad names, report rows, targeting, contacts, request/response bodies, filters,
tokens, and headers are excluded from logs. Profile/advertiser IDs can be
one-way pseudonymized when logs leave the local machine.

There is no telemetry or network destination other than the fixed TikTok API
origin.
Support bundles require a future design because seemingly harmless ad metadata
can be sensitive.

### 14.1 Threat model and trust boundaries

Protected assets are access tokens, the operation-specific app secret,
advertiser/report data, mutation authority, replay authority, and durable audit
evidence. Trust boundaries are CLI input to typed request builders, config to
secret resolution, ReaderCore to WriterCore, process to TikTok TLS, and writer
processes to the owner-only state filesystem.

| Threat actor or failure | Threat | Required control |
|---|---|---|
| Malicious/untrusted CLI or request file | Arbitrary URL/header/body injection, account escape, oversized input, duplicate-key ambiguity | Compiled catalogs, strict schemas, duplicate-key rejection, advertiser/operation allowlists, bounded parsing, validation before secrets/network. |
| Reader deployment or overprivileged token | Reader-to-writer escalation | Separate products/modules/profiles; ReaderCore has no WriterCore dependency; package, symbol, and negative CLI tests. |
| Redirect, proxy, challenge, or client library | Credential exfiltration or mutation replay | Fixed HTTPS origin/path, reject all redirects, ephemeral advertiser-list transport, one-shot writer body/task, no automatic mutation retry. |
| Concurrent process, crash, disk-full, or stale backup | Double dispatch, lost claim, replay-authority rollback | Crash-releasing global transaction lock, exclusive full-digest claim, fsynced authoritative generations, `CURRENT` plus `AUTHORITY`, exact-latest restore, fail-closed corruption handling. |
| Provider/network ambiguity or external operator | False success, unsafe resend, or rollback of someone else's change | Separate dispatch/provider/observation axes, mandatory readback, no causality claim, non-dispatching reconcile, explicit external-origin rollback acknowledgment. |
| Logs, errors, plans, diagnostics, caches, or fixtures | Secret/private-data disclosure | Secret references only, redaction-before-failure, no bodies/headers/free text, leak sentinels and persistence snapshots, owner-only bounded state. |
| Malformed/large provider response or report | Memory exhaustion, partial-output confusion, page loop | Response/structure/decoded/working-set caps, sequential bounded traversal, segmented no-copy output, atomic output-file option, closed partial-result contract. |
| TikTok documentation or entitlement drift | Wrong request, permission, enum, limit, or retry behavior | Pinned v1.3 catalog, all-disabled default, dated two-reviewer official evidence, contract fixtures, approved-app and sandbox gates. |

The effective local user, kernel, TLS trust store, and documented local
filesystem primitives are trusted. A hostile effective user, compromised OS,
TikTok service compromise, or locally undetectable rollback of the entire
state parent plus independent authority anchor is outside slice-one guarantees;
known or suspected occurrence permanently blocks mutation until a separately
designed external monotonic authority exists.

## 15. Testing and verification strategy

**Non-normative historical rationale:** Annex Section 16 is the sole
verification and release-gate contract.

### 15.1 Non-network automated verification

- Unit-test every operation's method, exact v1.3 path, required permission,
  header placement, query encoding, request body, ID string preservation,
  response envelope, and page metadata against sanitized official examples.
- Table-test profile capability, advertiser and operation allowlists, config
  file safety, unknown/duplicate fields, identifier bounds, version pinning,
  request-file schemas, rejection of free-form writer metadata, report
  combinations, and page/status limits.
- Prove validation/authorization failures occur before credential resolution
  with spies; prove reader code cannot construct or dispatch writer routes and
  neither CLI can register generic network `auth verify`.
- Use an injected transport for HTTP 200 with nonzero application code, 4xx,
  408/429/5xx, invalid JSON, oversized/truncated bodies, redirects, empty and
  repeated pages, missing `request_id`, cancellation, and timeouts.
- Use a real local HTTP server to prove reader and writer reject same-origin and
  cross-origin redirects before following. For writer, test HTTP/proxy/client-
  certificate challenges, replacement-body requests, connection loss, and
  connectivity changes; assert one server-observed mutation at most, no cookie/
  credential replay, and `possiblySent` for every runtime replay request.
- Use virtual time/deterministic jitter to prove retry counts, total budget,
  `Retry-After`, no retry of unknown codes, and no status-mutation resend.
- Test page metadata regression, changed totals, identical/conflicting duplicate
  IDs, report rows without stable keys, page reordering, no `--max-items`, no
  cross-invocation resume claim, and snapshot-consistency output. Exercise each
  cumulative item/encoded-byte/working-set boundary immediately below, at, and
  above the limit; prove the client stops before the next page, emits one
  complete partial document, and stays within measured peak memory. Adversarial
  fixtures cover deeply nested arrays/objects, escaped and Unicode-expanded
  strings, many tiny containers, maximum IDs, duplicate-index growth, decoded-
  object amplification, parser scratch, and simultaneous final-envelope
  encoding. Instrument allocator calls and peak resident memory during final
  output; prove segmented emission never allocates a second complete document,
  respects `maxOutputWriteBufferBytes`, and fails enablement if the runtime
  cannot provide tested no-copy behavior.
- Test complete-plan canonicalization/digest stability and mutation of every
  individual plan field. Prove plan ID alone has no claim authority and two
  concurrent actors applying the same unmodified plan digest produce exactly
  one transport dispatch and permanent replay rejection under the stated
  trusted-user scope.
- Run ordinary apply and rollback processes for distinct digests with identical,
  conflicting, partial-overlap, and disjoint resource sets across same/different
  profiles. Prove the writer-wide lock allows one dispatch workflow at a time,
  losers remain unclaimed, interrupted/unresolved aggregates block all writers,
  and recovery shares the same coordination gate.
- Test expiry before/during preflight, future-created times, invalid intervals,
  tolerated skew, wall-clock rollback, claim publication at the boundary, the
  monotonic dispatch deadline, and allowed post-expiry reconciliation. Test
  catalog/profile mismatch, final-read drift, and the documented external race.
- Inject termination or I/O failure after claim, after fsynced `dispatching`,
  after transport return, during mandatory readback, and before observation-
  journal persistence. Delete, truncate, replace, mismatch, and break the hash chain of
  every post-claim journal. Prove only an intact `reserved/notStarted` journal
  can finalize abandoned, missing/corrupt evidence becomes
  `storageIntegrityUnknown`, reconcile never dispatches, and all new mutations
  remain blocked pending manual inspection.
- Fault-inject global-lock open/validation/acquisition, each temporary create/
  write/fsync, journal rename, claim rename, directory fsync, dispatch-marker
  write/rename/fsync, abandoned finalization, cleanup, and quarantine. Assert
  every cut point selects exactly one disposition, cleanup rule, exit, and
  required action from the local durability table and never invokes transport.
- Test state initialization and epoch binding; inspect healthy/corrupt roots;
  create/verify backups; restore only an exact same-epoch/generation/root
  snapshot; reject stale backups; preserve corrupt originals; seal quarantine;
  fail reset without exact digests/acknowledgment; atomically create a new epoch;
  and reject every old-epoch plan and rollback manifest before token/network.
  Inject failure at every copy/fsync/CURRENT-switch cut point and prove the old
  epoch remains authoritative unless reset completes.
- For apparent success, HTTP/application rejection, timeout, malformed response,
  and cancellation, simulate every combination of desired/prior/divergent/
  missing/unreadable resource readback; prove every dispatched resource is
  classified, the first fair sweep attempts every chunk before repeats, later
  rounds rotate, and all observation snapshots remain immutable. Prove first-
  sweep requests never retry or honor backoff, each chunk receives its positive
  minimum slice, absolute first/total deadlines hold, cancellation latency is
  bounded, and retry/backoff occurs only in later rotated rounds. Reconcile from
  every post-dispatch observation state and prove it appends without dispatch.
- Cross-product-test the complete writer result/exit matrix, including accepted
  plus prior-observed, rejected plus desired-observed, unknown provider plus any
  observation, incomplete reads, and nondurable journal output. Assert provider
  outcome and causal attribution remain independent. Generate every valid
  pre-claim, post-claim, provider/observation, durability, and rollback aggregate
  state and assert exactly one exit code and exactly one required action; reject
  schema-invalid combinations.
- Test rollback grouping uses only currently desired-observed resources and
  requires the exact latest-observation external-origin acknowledgment. Test
  deterministic child order, aggregate claim exclusivity, pre-child durability,
  stale child stop, child failure, termination at every child cut point,
  reconcile-without-advance, explicit resume, and durable partial aggregate.
  Test
  config/writer file ownership, group/other writability, no-follow descriptor
  opens, path-swap races, size bounds, stable claim-inode locking, output mode,
  fsync failures, and exclusive create-without-overwrite.
- Run two independent reader processes in a test harness to prove limiters are
  process-local, then verify provider throttling remains bounded and redacted.
- Validate the evidence-manifest schema, all proposed entries default disabled,
  incomplete entries cannot enable, and first/second reviewers differ. Reject a
  writer when its safety read is missing, disabled, from another catalog
  revision, lacks exact-ID/status matching, exceeds compatible limits, lacks
  permission evidence, or lacks independent contract tests.
- Prove zero enabled operations fails feature production readiness. Enable each
  required operation in isolation and prove readiness remains false until the
  exact nine-operation minimum and all contract/permission/sandbox gates pass.
- Snapshot exact stdout/stderr and exit codes. Seed every secret-bearing field
  with unique fake sentinels and assert no sentinel or common encoding leaks.
- Run `mise run lint`, the narrow test target, `mise run test`, and
  `mise run build`; Swift implementation must also follow the repository Swift
  coding skill and run SwiftLint when available.

### 15.2 Official-contract and sandbox verification

Before enabling each catalog entry, the versioned evidence manifest records the
endpoint-specific official page URL, evidence date, exact method/path/
permission, required and optional fields, enums, page/batch/report limits,
gateway response/traversal/working-set/output-buffer bounds and tested segmented
no-copy assembly, response/error shape,
application codes, rate guidance, conditional-mutation support, batch rejection
atomicity, sanitized fixture provenance, and contract tests. Writer entries
also bind every safety read to the same catalog revision and prove its exact-ID
selection, stable ID/status projection, one-result-per-ID matching, permission,
limits, and tests. An independent second reviewer must substantively compare
the official page, manifest, code, and fixtures; the manifest rejects one-
person enablement. This is required because public docs are dynamic.

Optional live tests are opt-in, serial, read-only by default, and skipped unless
an approved sandbox profile and injected token exist. They may use
`taco-dev-sandbox@mutvar.com` only as the human-readable non-secret test
identity. Live reader checks list authorized advertisers, request one minimal
page for each reader, and run a minimal date-bounded report. Writer verification
uses a dedicated non-spending sandbox object, first confirms no delivery/budget
risk, then plan/applies one reversible status transition and applies a separate
rollback plan. No live test prints payloads or credentials.

Individual operation enablement requires app approval evidence, sandbox
success, exact permission review, verified limits/enums, redaction tests, and no
unresolved high/middle design or security findings. Full feature production
readiness additionally requires all nine Section 6.1 operation IDs enabled at
the same reviewed catalog revision. No live credential is required for ordinary
CI.

## 16. Cross-feature impacts and compatibility risks

**Non-normative historical rationale:** Annex Sections 14-15 are the sole
compatibility, precondition, lifecycle, and rollback-constraint contract.

- `Package.swift`: implementation will replace generic targets with shared,
  reader-core, writer-core, reader-executable, writer-executable, and matching
  test targets. Homebrew scripts must package both binaries and remove the
  unqualified product without installing an alias.
- CLI/README: the current greeting and single-binary usage will be replaced;
  help, installation, configuration, secret injection, exclusive apply claims,
  writer-wide coordination, interrupted-apply reconciliation, complete-digest
  replay rejection, observation-only outcomes, deterministic result/action
  matrix, external-origin rollback acknowledgment, readiness status, and non-
  snapshot bounded pagination must distinguish capabilities.
- WriterCore and ApplyJournalStore own the stable global mutation lock, durable
  integrity scan, private claims/hash-chained journals, fair reconciliation,
  immutable observations, state epochs, inspection/backup/quarantine/reset, and
  multi-child rollback aggregates. Plan and rollback schemas include the epoch.
  Backup, retention, migration tests, and future pruning must preserve old
  epochs and post-dispatch journals, which remain refreshable and may block
  dispatch.
- Reader and writer transports reject all redirects; writer additionally owns
  a one-shot no-replay adapter. Shared transport protocols cannot weaken these
  capability-specific policies.
- Release workflows: formula/cask artifact lists, signing, smoke tests, and
  tap rendering may assume one executable and need a reviewed update.
- Configuration: schema v1 is new; there is no existing user data migration.
  Future schema/API versions must coexist explicitly and never silently upgrade.
- The evidence manifest becomes a versioned release input. Catalog generation,
  fixtures, tests, and enablement must fail closed when it is incomplete or its
  independent review is missing. Writer catalog generation additionally joins
  and validates same-revision safety-read dependencies and absolute fair-sweep
  deadlines; ReaderCore materializes cataloged structural, decoded, envelope,
  output-write-buffer, cumulative traversal, simultaneous-memory bounds, and
  segmented no-copy output. Release metadata must expose framework acceptance
  separately from nine-operation readiness.
- Process-local reader limits do not aggregate across CLI invocations. A future
  profile-wide limiter would add interprocess coordination and cleanup distinct
  from the writer apply journal.
- Strict descriptor-based ownership/mode rules can reject team-shared config or
  writer files that the scaffold previously accepted; reader-only fixtures have
  the documented narrower exception.
- Reference-gateway parity: shared safety concepts are retained, but TikTok
  permission, error, pagination, and report semantics must not be copied from
  Google.
- API evolution: v1.3 ID/report changes demonstrate that a version bump can be
  source- and data-incompatible. The pinned catalog and fixture gate contain
  this risk.
- Human roles and app permissions are adjacent but non-equivalent. Analyst vs
  Operator/Admin access in Business Center does not replace local capability
  checks or prove app authorization.
- Security review scope after implementation is the explicit repository and
  target paths, not only recent changes.

## 17. Provisional decisions

**Non-normative summary:** The user-decisions document named below is the sole
provisional-decision contract.

Detailed review entries are recorded in
`design-docs/user-qa/tiktok-business-gateway-decisions.md`.

1. Slice one pins Marketing API v1.3 and supports manual campaign/ad-group/ad
   reads plus integrated reports; Smart+/GMV Max are excluded.
2. Separate executables and client modules enforce the reader/writer boundary.
3. Writer scope is limited to status changes with durable single-use claim,
   writer-wide serialization, one-shot transport, pre-dispatch journal,
   mandatory per-resource reconciliation, and no claim of provider compare-and-
   set or mutation causality; creation, general update, and budget changes are
   deferred.
4. Marketing API credentials are externally provisioned via environment
   references; automated authorization/refresh/revocation is deferred.
5. Pagination defaults to one page; cataloged cumulative, structural, decoded,
   envelope, output-buffer, and simultaneous-memory bounds plus segmented no-
   copy output stop traversal at page boundaries. Traversal is non-snapshot and
   has no cross-invocation resume guarantee.
6. A process-local cap of one in-flight read per profile and two starts per
   second applies until approved-app/endpoint limit evidence is recorded.
7. Remove the existing unqualified executable in slice one; ship no shim,
   alias, wrapper, or deprecation route.
8. All proposed API operations remain disabled until their versioned evidence-
   manifest entries are complete and independently reviewed; the feature is not
   production-ready until all nine slice-one operations are enabled and pass
   contract, permission, and sandbox gates.
9. Writer requests contain no free-form reason or audit text.
10. `auth status` is local-only and generic network `auth verify` is absent;
    provider authorization is exercised only through cataloged operations.
11. Complete plan digest, not plan ID, is replay identity; single-use protection
    is scoped to unmodified, current-epoch gateway plans under a trusted
    effective local user.
12. Every post-dispatch read is an immutable observation with unknown causal
    origin; rollback requires explicit acknowledgment of external-origin risk.
13. Multi-child rollback requires an explicit durable execute/reconcile/resume
    lifecycle, shares writer-wide coordination with apply, and stops rather than
    skipping a stale or uncertain child.
14. All mutation dispatch is writer-wide serialized; unresolved/corrupt durable
    state blocks ordinary apply and rollback across profiles and resources.
15. Writer transport rejects all redirects and replay paths and treats any
    runtime resend request as possibly sent.
16. Framework-design acceptance is separate from full feature production
    readiness, whose minimum is all nine proposed operations.
17. Irrecoverable writer-state corruption requires sealed quarantine, explicit
    possible-prior-dispatch acknowledgment, and a new epoch that invalidates all
    old plans; corrupt evidence is retained.
18. Reader final output uses tested segmented no-copy assembly; an
    implementation that coallocates a complete document must use a stricter
    memory formula and cannot claim the segmented strategy.

These choices are conservative, reversible at design boundaries, and avoid
claiming undocumented provider behavior.

## 18. Design review checklist and routing gate

### 18.1 Node 2 deep-review remediation

| Severity | Feedback | Design resolution |
|---|---|---|
| High | Crash-safe pre-dispatch evidence and restart recovery | Section 10.3 defines immutable claim, fsynced `dispatching` journal before transport, durable cut-point states, and dispatch-free reconcile. |
| High | Atomic single-use across concurrent/replayed apply | Section 10.3 uses exclusive claim creation keyed by complete plan digest plus stable claim and writer-wide locks; every claim consumes the plan. |
| High | Readback after rejection and possible partial batch application | Section 10.3 requires per-resource readback after every dispatched outcome and persists desired/prior/divergent/missing/unreadable classifications. |
| High | Unachievable unchanged-precondition guarantee | Acceptance criterion 4 and Sections 6.2/10.3 explicitly deny compare-and-set unless official evidence proves it and retain the external-race residual risk. |
| Medium | Endpoint matrix overstated as verified | Section 6.1 marks every operation proposed/disabled and adds the versioned machine-readable evidence manifest. |
| Medium | Pagination duplicates, ordering, snapshot, and resume ambiguity | Section 9.2 defines validation, deduplication, conflicting duplicates, non-snapshot semantics, no mid-page cap, and no cross-run resume claim. |
| Medium | Rate-limit scope unclear | Section 12 makes the limiter process-local and records aggregate multi-process throttling risk. |
| Medium | File ownership/mode/check-open gaps | Section 8.2 requires no-follow open, descriptor checks, current-user ownership for trust-bearing files, safe modes, bounds, fsync, and a narrow reader exception. |
| Medium | Free-form plan reason can contain secrets | Section 10.2 removes all free-form writer metadata; plan ID is the external correlation key. |
| Medium | Writer `auth verify` conflicts with capability invariants | Sections 8.1/13 ultimately remove generic network verification from both binaries and require negative tests. |

All ten findings are addressed in this author revision. Their prior review
severity remains historical evidence; acceptance and downstream routing stay
false until independent re-review confirms zero unresolved high/medium findings.

### 18.2 Second Node 2 deep-review remediation

| Severity | Feedback | Design resolution |
|---|---|---|
| High | Observations were treated as mutation causality | Sections 10.3/11 separate dispatch evidence, provider outcome, and immutable observation history; causal attribution is always unknown, and rollback requires external-origin acknowledgment. |
| Medium | Digest/replay identity and trust boundary incomplete | Sections 7.2/10.2 digest every plan field, key claims by full digest, make plan ID non-authoritative, and scope protection to unmodified gateway plans under the trusted-user model. |
| Medium | Unfair readback and no terminal refresh | Section 10.3 guarantees a first attempt for every deterministic chunk before repeats, rotates later rounds, and permits append-only reconciliation from every post-dispatch state. |
| Medium | Writer safety-read dependencies absent | Sections 6.1/15.2 and the evidence manifest require same-revision, independently enabled and contract-tested dependencies with compatible selection, status projection, permissions, and limits. |
| Medium | Plan-expiry authorization instant undefined | Section 10.2 validates future/skew/rollback conditions, rechecks expiry immediately before atomic claim publication, and uses a monotonic 30-second dispatch deadline. |
| Medium | Multi-child rollback execution/recovery undefined | Section 10.4 defines durable aggregate claim/state, deterministic child order, stop/reconcile/resume behavior, and stale-child fail-closed handling. |
| Medium | Writer output/exit cross-product undefined | Section 11 defines the independent result envelope and total first-match exit/action matrix. |
| Medium | Pagination lacked cumulative resource bounds | Section 9.2 and the evidence manifest require item, encoded-byte, response, and working-set bounds enforced before each next-page request. |

All eight second-review findings are addressed in this author revision. The
historical review severity was one high and seven medium; acceptance remains
false until independent deep re-review verifies zero unresolved high/medium.

### 18.3 Third Node 2 deep-review remediation

| Severity | Feedback | Design resolution |
|---|---|---|
| High | Distinct overlapping plans and rollback could dispatch concurrently | Section 10.3 introduces conservative writer-wide serialization, unresolved-state scanning, shared recovery coordination, and no plan consumption on lock contention; Section 10.4 holds the same lock across rollback children. |
| High | Same-origin redirect or client replay could resend a mutation | Sections 7/10.3/12 reject every redirect and replay-capable challenge, require a one-use body/no second task, classify runtime replay requests as possibly sent, and require real-server verification. |
| Middle | Missing journal was incorrectly proof of no dispatch | Section 10.3 publishes a valid reserved journal before claim authority, states the filesystem integrity assumption, and makes missing/corrupt post-claim evidence block all mutations as `storageIntegrityUnknown`. |
| Middle | Fair sweep conflicted with safe-read retries and cancellation | Section 10.3 disables retries/backoff in the first sweep, guarantees positive per-chunk slices, and catalogs absolute first-sweep, total, and cancellation deadlines. |
| Middle | Decoded and final-envelope memory amplification unbounded | Section 9.2 requires bounded incremental parsing, structural/decoded/dedup/envelope fields, and an explicit simultaneous-buffer formula. |
| Middle | Writer matrix contained alternative exits/actions | Section 11 enumerates mutually exclusive pre-claim and provider/observation predicates with exactly one exit/action and fixed rollback child-action precedence. |
| Middle | Zero enabled operations could vacuously satisfy delivery | Sections 5/15.2 and the evidence manifest separate framework acceptance from production readiness and require all nine slice-one operations for full delivery. |

All seven third-review findings are addressed in this author revision. The
historical review severity was two high and five middle; acceptance remains
false until independent deep re-review verifies zero unresolved high/middle.

### 18.4 Fourth Node 2 deep-review remediation

| Severity | Feedback | Design resolution |
|---|---|---|
| Middle | Final output could duplicate retained encoded bytes | Section 9.2 and manifest schema v4 mandate tested segmented no-copy assembly, add a bounded output-write buffer, forbid a second complete-document allocation, and require stricter accounting when no-copy cannot be proved. |
| Middle | Pre-claim and claim-publication durability failures were unmapped | Section 11 enumerates lock, temporary file, write/fsync, journal publication, claim publication, directory fsync, dispatch-marker, finalization, and cleanup outcomes with one disposition, exit, action, and cleanup rule. |
| Middle | Irrecoverable integrity state had no safe recovery lifecycle | Sections 10.2/10.5 bind plans to state epochs and define non-dispatching inspection, exact backup restoration, sealed quarantine, explicit possible-prior-dispatch acknowledgment, atomic new-epoch reset, audit output, and old-epoch rejection. |

All three fourth-review findings are addressed in this author revision. The
historical review severity was zero high and three middle; acceptance remains
false until independent deep re-review verifies zero unresolved high/middle.

### 18.5 Pass-5-through-8 remediation incorporated from the safety annex

The normative annex Section 17 records four additional Node 2 rounds: 11 high
and 21 medium/middle findings raised, all addressed in the author revisions.
Those revisions add the operation-specific app-secret boundary; single-resource
status dispatch; one crash-releasing transaction lock for every writer-state
command; bounded plans, children, state, observations, and deadlines; RFC 8785
domain-separated digests and profile-authorization fingerprints; authoritative
per-transition `CURRENT` generations; independent `AUTHORITY` anti-rollback;
exact-latest self-contained restore; permanent mutation blocking after unknown
state; boot/continuous-time expiry; atomic output files; nonpersistent
`advertisers.list` transport; two-phase rollback terminalization; and the
explicit unsupported whole-parent-restore boundary. Known unresolved high or
medium/middle author findings are zero. Independent acceptance is still
required and may identify new findings.

### 18.6 Consolidation deep-review remediation

| Severity | Feedback | Design resolution |
|---|---|---|
| High | Ambiguous outcomes were globally blocking but also pointed to an ineligible rollback | Normative Annex Sections 8-9 remove ambiguous rollback actions, require accepted-plus-desired eligibility, and add digest-bound non-network ambiguity closure that permanently denies only affected resources while preserving every unrelated block. |
| Middle | Root and annex exposed conflicting CLI and lifecycle contracts | The root introduction now assigns a sole normative source per topic, explicitly covering commands, schemas, state transitions, exits, rollback, restore, and reset; all competing variants are non-normative. |
| Middle | Universal absence of proxy/request-history persistence was untestable | Normative Annex Section 6 defines inspectable runtime/proxy preconditions, bounded gateway-local leak evidence, a dated deployment attestation, and an explicit uninspectable external-network trust boundary. |

All three findings are addressed in this author revision. Known unresolved high
or medium/middle author findings are zero; independent deep re-review remains
required.

### 18.7 Second consolidation deep-review remediation

| Severity | Feedback | Design resolution |
|---|---|---|
| High | Rejection plus `allPrior` could terminalize despite unproven rejection atomicity | Normative Annex Sections 8-9 require one bounded non-dispatching reconciliation for every rejection-plus-allPrior first observation; a repeated all-prior observation closes only through `ambiguityPending` and permanent affected-resource denial. |
| Middle | The `advertisers.list` deployment attestation was not testable or environment-bound | Normative Annex Section 6 defines a fixed owner-controlled path, closed schema v1, canonical digest, deployment/network/profile/runtime/catalog bindings, 24-hour maximum lifetime, invalidation rules, pre-secret validation, and negative fixtures. |
| Middle | Cancellation finalization used conflicting bounds | The precedence table, normative writer lifecycle, evidence manifest, deadline arithmetic, and fixtures now require exactly two seconds as the no-new-work/start-finalization deadline with explicit blocked-syscall handling. |
| Middle | The designated CLI source was representative rather than exhaustive | Normative Annex Section 11 now enumerates every slice-one command and flag and defines shared flags, required output, mutual exclusions, pagination, lock/config rules, and rejected syntax. |

All four attempt-2 findings are addressed in this author revision. The review
raised one high and three middle findings; known unresolved high or
medium/middle author findings are zero. Independent deep re-review remains
required.

### 18.8 Third consolidation deep-review remediation

| Severity | Feedback | Design resolution |
|---|---|---|
| High | Rollback rejection plus prior observation could terminalize without denial | Annex Section 8 now requires bounded rollback reconciliation and routes every persistent rejection-plus-prior result through rollback ambiguity acknowledgment and permanent affected-resource denial. |
| High | The normative writer-state root was unresolved | Annex Section 8 defines one effective-user account-record Application Support path, descriptor requirements, no overrides, a finite legacy-root catalog, and fail-closed alias/split-state discovery. |
| Middle | Clock rollback could revive an expired deployment attestation | Annex Section 6 binds attestations to boot session and continuous issuance time, invalidates them on reboot, and adds a durable per-boot wall-clock high-water checked before secrets. |
| Middle | Cancellation during blocking durability lacked deterministic deadline behavior | Annex Section 8 defines the two-second absolute no-new-work/start-finalization deadline, the last authoritative CURRENT state, uninterruptible syscall handling, result timing, and crash fixtures. |
| Middle | Rollback observation confirmation and external-origin acknowledgment were conflated | Annex Sections 8 and 11 require a domain-separated `--observation-digest` plus a separate literal `--ack-external-origin-risk`. |
| Middle | Quarantine and reset lacked complete transitions and crash behavior | Annex Section 8 defines inspection binding, quarantine reasons/schema/digest, atomic publication, mutation blocking, idempotency, crash recovery, and permanently blocking reset. |
| Middle | Archive confirmation was circular | Annex Sections 8 and 11 define non-mutating `state archive-plan` followed by digest-confirmed `state archive`, with safe crash and retry behavior. |
| Middle | The optional compatibility product made the exhaustive grammar incomplete | The product is removed in slice one; no shim, alias, wrapper, symlink, or deprecation route is shipped. |

All eight attempt-3 findings are addressed in this author revision. The review
raised two high and six middle findings; known unresolved high or
medium/middle author findings are zero. Independent deep re-review remains
required.

### 18.9 Fourth consolidation deep-review remediation

| Severity | Feedback | Design resolution |
|---|---|---|
| Middle | Cancellation semantics were incomplete and conflicted across lifecycle commands | Annex Section 8 now supplies a command-by-command cancellation matrix for every writer and lifecycle command, with authoritative cut points, the absolute two-second deadline, blocked-syscall behavior, output, crash recovery, and idempotent retry. |
| Middle | Quarantine could strand authority without a recovery or permanent-disable acknowledgment | Annex Sections 8 and 11 make quarantine an irreversible authority transition, require literal permanent-disable acknowledgment, require closed structural evidence for structural-corruption claims, and define its staged/final/crash states. |
| Middle | The result action contract omitted rollback and lifecycle actions | Annex Sections 9 and 11 define a closed discriminated result union with disjoint apply, rollback, lifecycle, utility, and pre-result error schemas and exhaustive action enums. |
| Middle | Rollback planning left provider reads and no-op manifests ambiguous | Annex Section 8 makes `rollback-plan` strictly local and non-network, emits only actionable children, removes no-op/mixed manifest classes, and assigns fresh provider reads only to inspect, execute safety checks, reconcile, and resume. |
| Middle | The first usable `allPrior` observation could close ambiguity without a later confirmation | Annex Sections 8-9 persist attempt and usable-observation sequences and require a later usable `allPrior` observation with a greater attempt sequence before confirmation. |
| Middle | Alternate writer-state-root discovery was unbounded | Annex Section 8 defines `legacyStateRoots.v1`, exactly three roots and the later-expanded eight-marker transition-evidence catalog, descriptor-only non-recursive probing, deterministic failure, and an explicit boundary for uncataloged locations. |

All six attempt-4 middle findings are addressed in this author revision. Known
unresolved high or medium/middle author findings are zero; independent deep
re-review remains required.

### 18.10 Writer-state rerun remediation

| Severity | Feedback | Design resolution |
|---|---|---|
| High | The normative annex used an undefined fixed writer-state parent | Annex Section 8 now defines `canonicalStateParent` as one exact effective-user account-record path for every release and executable, forbids overrides, and fixes the lock, CURRENT, AUTHORITY, epoch, checkpoint, backup, quarantine, and migration child locations. |
| High | Universal pre-lock legacy rejection made inspection, quarantine, and migration unreachable | Annex Sections 8, 9, and 11 now acquire the canonical lock before discovery, permit only non-network inspect and exact-digest recovery commands on detected evidence, add a single-valid-lineage `state migrate-legacy` flow with a compatible source freeze lock and retirement acknowledgment, and keep actual split/invalid state quarantine-only. |

Both high findings are addressed in this author revision. Known unresolved high
or medium/middle author findings are zero; independent deep re-review remains
required.

### 18.11 Writer-state follow-up remediation

| Severity | Feedback | Design resolution |
|---|---|---|
| Middle | Migration fresh-start authority absence contradicted post-activation retry | Annex Sections 8 and 11 separate fresh-start predicates from five INTENT-bound resume phases, bind the only permitted canonical root at each phase, and define source-lock reacquisition, last-lock-unlink recovery, and post-retirement no-recreation. |
| Middle | Preserved legacy markers made post-reset export and maintenance unreachable | Annex Section 8 defines `postResetMaintenanceCommands.v1`, requires permanently blocked authority plus an exact quarantine-seal candidate match, and re-blocks maintenance on any drift without enabling dispatch. |
| Middle | Quarantine could copy concurrently changing legacy evidence | Annex Sections 8 and 11 acquire all compatible source locks in deterministic order, forbid busy-lock bypass, require explicit quiescence for incompatible sources, and revalidate the complete inspection digest before and after descriptor-based copying. |

All three middle findings are addressed in this author revision. Known
unresolved high or medium/middle author findings are zero; independent deep
re-review remains required.

### 18.12 Transition-evidence follow-up remediation

| Severity | Feedback | Design resolution |
|---|---|---|
| High | Legacy discovery omitted authority-bearing migration artifacts when ordinary markers were absent | Annex Section 8 defines `legacyEvidenceMarkers.v2` as all eight canonical state-bearing child names, performs exactly 24 no-follow probes, and treats a sole valid/corrupt/unreadable migrations marker as evidence that blocks initialization and dispatch. |
| Middle | Compatible-lock post-reset maintenance omitted final all-root drift validation | Annex Section 8 requires every maintenance method to repeat the complete 24-probe all-root candidate/seal comparison after its last canonical work and immediately before result publication, suppressing output on any drift. |
| Middle | Pending migration inputs were undiscoverable after output loss or handoff | Annex Sections 8, 9, and 11 make inspect emit one closed non-secret pending-migration tuple and add mutually exclusive digest-only resume syntax that derives immutable inputs from the validated INTENT. |

All three findings are addressed in this author revision. Known unresolved high
or medium/middle author findings are zero; independent deep re-review remains
required.

### 18.13 Post-reset reseal follow-up remediation

| Severity | Feedback | Design resolution |
|---|---|---|
| Middle | Candidate drift named quarantine/reset recovery without authority transitions from permanently blocked reset state | Annex Sections 8, 9, and 11 define inspection-bound `post-reset-candidate-drift` re-quarantine, predecessor-linked replacement-seal CURRENT/AUTHORITY fields, crash-safe/idempotent direct transition to quarantined authority, and exact-current-seal re-reset carrying the latest maintenanceBaseRoot and all committed maintenance changes. |

The finding is addressed in this author revision. Known unresolved high or
medium/middle author findings are zero; independent deep re-review remains
required.

### 18.14 Routing state

- `designAuthorComplete`: true
- `knownHighOrMediumFindingsUnresolved`: false
- `deepReviewCompleted`: true
- `deepReviewPassed`: false
- `routeToIndependentDeepReview`: true
- `routeToBroadReview`: false
- `routeToAdversarialReview`: false
- `independentReviewsPassed`: false
- `routeToImplementationPlan`: false
- `routeToImplementation`: false
- `routeToSourceSecurityCheck`: false
- `authenticatedSmokePassed`: false
- `featureProductionReady`: false

An independent reviewer must challenge at least:

- reader-to-writer escalation, writer-profile overbreadth, arbitrary URL/path/
  header injection, all redirects, challenge/replay behavior, descriptor/path-swap attacks,
  ownership/mode enforcement, secret leakage, validation order, and provider
  error ambiguity;
- ID precision, query encoding, page loops, report explosion, response limits,
  duplicates/reordering, snapshot limitations, timeout/cancellation, retry
  storms, decoded-memory amplification, concurrent/replayed/overlapping apply,
  apply-versus-rollback coordination, crash cut points, missing/corrupt journal,
  fsync failure, stale leases, mandatory rejection readback, fair-sweep deadlines,
  partial batch results, external status races, rollback hazards, and API drift;
- target/product renames, packaging of exactly two executables, removal of the
  old unqualified product, live-test isolation, and the distinction between human roles, app
  permissions, and advertiser authorization;
- every official-source claim and every uncertainty/release gate;
- the separation between framework acceptance, partial previews, and the exact
  nine-operation feature-production readiness minimum; and
- output allocation traces, every local durability cut point, epoch-root
  transactions, exact canonical state-parent/lock/AUTHORITY resolution,
  lock-before-legacy-discovery ordering, reachable digest-bound legacy
  inspection/migration/quarantine, phase-specific migration crash cuts and
  source-lock retirement, migrations-only legacy evidence, pending-migration
  handoff, stable quarantine capture, final all-root sealed post-reset
  maintenance validation, exact/stale backup restoration, quarantine
  preservation, post-reset replacement-seal/re-reset crash recovery, committed
  maintenance carry-forward, reset acknowledgments, and old-epoch rejection.

Implementation-plan routing is false until this design is accepted and all
high/medium findings from deep, broad, and adversarial review are resolved.
After acceptance, route sequentially to `codex-impl-plan-completion-loop`.
Security-routing readiness remains false until implementation and plan
completion; then route to `codex-source-security-check-loop` with the explicit
repository/target scope.

## 19. Residual risks

**Non-normative historical list:** Annex Section 19 is the sole residual-risk
register.

- TikTok documentation is dynamic and some details are visible only through the
  developer portal/app context; exact limits, enums, and codes may remain
  uncertain until implementation-time evidence capture.
- Developer-app approval, permissions, advertiser grants, sandbox behavior, and
  regional/policy restrictions cannot be proven by repository-only checks.
- Status changes can affect live delivery and spend. The local single-use claim
  does not prevent Ads Manager, another machine, or direct API clients from
  changing state between the final read and mutation; no provider compare-and-
  set or batch-rejection atomicity is assumed.
- Post-dispatch observation cannot establish who caused a status or whether a
  different status existed transiently; rollback can reverse an unrelated
  external change even after explicit acknowledgment.
- Process death, disk-full, or local-state corruption after dispatch can still
  require repeated reconciliation and manual provider inspection. The design
  prevents automatic resend but cannot manufacture missing provider evidence.
- Writer-wide serialization deliberately lets one unresolved or corrupt journal
  block unrelated profiles and resources; recovery availability is favored over
  writer throughput.
- No hash chain protects against the trusted effective user deliberately
  altering all local state, and unsupported filesystem durability semantics are
  outside the safe deployment contract.
- Irrecoverable epoch reset restores local availability only by explicitly
  accepting that a prior dispatch may be unknown; it cannot reconstruct lost
  provider causality or safely reuse old plans.
- The one-shot writer guarantee depends on the selected networking adapter
  passing real redirect/challenge/connection-loss tests; an adapter with hidden
  replay behavior cannot be used.
- Page-based traversal has no snapshot-isolation guarantee and may miss or
  reorder resources during concurrent provider changes even when the end page
  is observed.
- Conservative structural and simultaneous-memory bounds can reject legitimate
  large provider pages until reviewed catalog values and implementations prove
  a safe higher ceiling.
- Segmented output depends on allocation and peak-memory tests proving that the
  runtime does not create a hidden complete-document copy.
- Process-local rate limiters do not coordinate concurrent CLI processes, so
  aggregate traffic can exceed the intended local rate and be throttled.
- A local environment variable is process-accessible to the executing user;
  future Keychain integration may reduce exposure but needs separate design.
- Indefinitely retained claims, observations, and rollback journals contain
  private advertiser identifiers and status history; no automatic pruning is
  designed in slice one.
- Backups, recovery candidates, and sealed quarantine preserve additional
  copies of that private operational history and require operator-controlled
  retention and storage protection.
- TikTok may deprecate v1.3 or change report semantics before implementation;
  the official-evidence gate must be rerun on the implementation date.
- The current all-disabled catalog is framework-design evidence only and cannot
  deliver production reader or writer capability.
- The whole current worktree is untracked, so future changes need careful
  changed-file review to distinguish scaffold content from feature work.

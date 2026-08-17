# Practical TikTok Business Gateway Implementation Plan

**Status:** Implemented; local build/tests/HTTP checks complete, with SwiftLint
and authenticated smoke availability recorded in the final verification

**Scope:** SwiftPM gateway with nine enabled, fixed TikTok Marketing API v1.3
reader and direct status-update operations backed by the repository's reviewed
official endpoint matrix and synthetic local contract fixtures.

## Decisions

- Build separate shared, reader, and writer library targets, plus distinct
  reader and writer executable products.
- Keep reader operations in Shared's read-only catalog and mutation operations
  plus POST request construction in WriterCore; accept no caller-defined
  network surface and fail closed outside the reviewed manifests.
- Parse non-secret profile configuration first, authorize capability,
  operation, and advertiser next, and resolve environment credentials last.
- Inject `Access-Token` centrally. Resolve app ID/app secret only for
  `advertisers.list`; never render requests, headers, or secrets in errors.
- Decode HTTP status and TikTok `code` independently, bound response bytes
  during receipt, reject redirects, and expose transport/sleeper/credential
  seams for deterministic tests.
- Retry safe reads for bounded transient HTTP outcomes. Surface ambiguous
  TikTok application throttle codes without retry. Retry writes only when the
  transport can prove the failure occurred before dispatch.
- Model advertiser, campaign, ad-group, ad, report, and page values without
  converting provider identifiers to numbers or monetary metrics to binary
  floating point.
- Limit writes to one resource and `ENABLE`/`DISABLE`; require a closed
  `MANUAL` resource-family assertion and exact CLI confirmation, force ad-group
  partial success off, and offer no delete route.

## Work completed

1. Replaced the scaffold package graph with shared, reader, writer, and CLI
   targets.
2. Implemented configuration validation, environment credential resolution,
   redaction, operation catalog, bounded HTTPS transport, retry/backoff, typed
   TikTok envelopes, JSON output, and stable error categories.
3. Implemented and enabled all requested reader and writer client methods and
   CLI routes behind the fixed production evidence catalog.
4. Added deterministic transport/request/model/auth/retry/safety tests.
5. Updated README and reconciled the design documents to mark speculative
   durable writer state as deferred and non-implemented.

## Verification gates

- Swift files stay below 1000 lines.
- SwiftLint was unavailable: no direct executable was installed and mise was
  blocked by the repository configuration's untrusted status. Swift formatting,
  builds, and tests remain the available local gates.
- Focused and full `swift test` pass.
- `swift build` and both executable help/catalog paths pass.
- The release reader artifact contains no mutation routes or writer request
  builders.
- A safe unauthenticated HTTPS reachability check reaches the fixed TikTok
  endpoint without sending credentials.
- Authenticated smoke runs only when the documented environment already
  supplies configuration and credentials; mutation smoke additionally requires
  a separately confirmed non-serving resource already in the target state.
- Final source review resolves every high- and medium-severity finding.

## Explicitly deferred

Durable plan claims, journals, replay tombstones, drift/readback orchestration,
rollback manifests, quarantine, archive, backup/restore, epoch rotation, and
automatic credential lifecycle are not implemented. They remain a separate
project because they materially expand local state authority and recovery
semantics.

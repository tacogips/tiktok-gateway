# TikTok Business Gateway Provisional Decisions

**Status:** Historical pre-implementation decisions; non-normative

**Authority:** None. The practical reconciliation and schema-v5 evidence
manifest supersede this file.

No user response is required before independent design review. A later change
must update both authoritative design files, the evidence manifest, tests, and
review findings before implementation.

## 1. Initial API surface

- **Decision:** Pin Marketing API v1.3 and only propose authorized-advertiser,
  advertiser, manual campaign/ad-group/ad, BASIC synchronous-report, and three
  manual status operations. Every operation starts disabled.
- **Why confirmation would normally be needed:** Product priorities may favor
  Smart+, GMV Max, async reports, campaign creation, or broader automation.
- **Why this is preferable:** It is the smallest useful ads surface with current
  first-party documentation and bounded spend risk.
- **If later rejected:** Amend the allowlist with exact official method, path,
  permission, version, schema, limits, risk controls, fixtures, and independent
  review; never enable an undocumented operation by configuration.

## 2. Reader/writer deployment boundary

- **Decision:** Use separate reader and writer modules and executables; Shared
  has no concrete dispatcher, ReaderCore cannot import WriterCore, and the
  writer uses ReaderCore only for fixed safety reads.
- **Why confirmation would normally be needed:** Multiple products affect
  packaging, installation, release scripts, and user ergonomics.
- **Why this is preferable:** The reader artifact is structurally incapable of
  constructing a mutation, not merely protected by a runtime flag.
- **If later rejected:** A consolidated binary needs an equally strong linkage
  boundary, separate profiles/entry paths, negative symbol and route tests, and
  renewed adversarial review.

## 3. Credential lifecycle and account authority

- **Decision:** Consume externally provisioned long-term Marketing API tokens
  from named environment variables. `advertisers.list` alone may additionally
  resolve a named app secret through a dedicated ephemeral transport, but only
  on a release-tested runtime with inspectable no-proxy settings and a dated
  deployment-owner attestation for uninspectable external infrastructure. The
  attestation is a closed schema-v1 document at the fixed owner-controlled
  profile path, expires within 24 hours, binds deployment, network boundary,
  authorization fingerprint, executable, runtime, OS, catalog, API origin and
  app ID, boot session, and continuous issuance time. Reboot invalidates it;
  continuous elapsed time and an owner-controlled wall-clock high-water prevent
  clock rollback from reviving it. It is revalidated before secret resolution. Do not implement
  authorization callbacks, code exchange, token storage, refresh, or
  revocation. `auth status` is local-only; generic `auth verify` is absent.
- **Why confirmation would normally be needed:** Operators may expect an
  interactive login or Keychain-backed durable credentials.
- **Why this is preferable:** TikTok's public callback and app-secret exchange
  materially expand attack surface, while human Business Center role, app
  permission, advertiser grant, and local profile authorization remain separate.
- **If later rejected:** Create a separate authentication-lifecycle design for
  state, callback ownership, token family, Keychain storage, revocation,
  recovery, redaction, app-secret URL-leak testing, and any supported proxy or
  TLS-inspection deployment.

## 4. Pagination, reports, and rate policy

- **Decision:** Fetch one page by default. `--all-pages` requires a bounded
  `--max-pages`; traversal is sequential, non-snapshot, non-resumable, and
  limited by page, item, encoded-byte, structure, decoded-memory, envelope,
  output-buffer, and working-set caps. Each process permits one in-flight read
  per profile and two starts per second, configurable only downward.
- **Why confirmation would normally be needed:** Consumers may prefer full
  automatic traversal, streaming, or higher throughput.
- **Why this is preferable:** Public Basic defaults do not prove the approved
  app's limits, and page-number pagination cannot promise snapshot consistency.
- **If later rejected:** Specify a bounded streaming/resume contract and record
  current approved-app and endpoint limits before changing catalog policy.

## 5. Writer scope and dispatch semantics

- **Decision:** Allow only `ENABLE` and `DISABLE` for one manual campaign, ad
  group, or ad per provider request. Reject `DELETE`, ACO ads, Reach-and-
  Frequency groups, campaign postback-window mutation, and partial success.
  Use plan/apply, complete-digest confirmation, one-shot no-replay transport,
  and mandatory readback after every possible dispatch.
- **Why confirmation would normally be needed:** Business workflows may require
  bulk mutation, budget/bid changes, or creation.
- **Why this is preferable:** Single-resource reversible intent limits blast
  radius where provider compare-and-set, idempotency, rejection atomicity, and
  causal readback are not established.
- **If later rejected:** Add each mutation as a separately evidenced catalog
  entry with idempotency/ambiguity analysis, spend controls, sandbox tests, and
  independent review.

## 6. Plan and local state trust boundary

- **Decision:** Plans are short-lived, boot/continuous-time-bound, canonical
  RFC 8785 documents whose full domain-separated SHA-256 digest is replay
  identity. Bind non-secret authorization fingerprints and the state epoch.
  Trust only owner-controlled, no-follow, descriptor-validated local files.
- **Why confirmation would normally be needed:** Strict ownership and expiry
  rules can hinder shared/team workflows.
- **Why this is preferable:** Authorization inputs and replay identity remain
  deterministic without placing secrets or free-form text in artifacts.
- **If later rejected:** Define signed configuration or a trusted-group model,
  new key lifecycle, conflict semantics, and renewed security review.

## 7. Durable writer recovery and rollback

- **Decision:** Serialize every writer-state command with one crash-releasing
  transaction lock. Commit claim, active child, dispatching, provider outcome,
  observation, receipt, and rollback transitions as separate authoritative
  generations. Every writer and lifecycle command follows a closed cancellation
  matrix: exactly two seconds is the absolute no-new-work/start-finalization
  deadline, and an already-entered uninterruptible durability syscall completes
  under explicit last-authoritative-state/crash rules. Never redispatch a
  claimed or unfinished child. `rollback-plan` is local and non-network and
  emits only actionable children. Every non-clean first rollback observation,
  including rejection-plus-allPrior, requires bounded non-dispatching
  reconciliation; the first usable allPrior observation always requires a later
  usable confirmation. Persistent ambiguity closes only with permanent
  affected-resource denial. Rollback requires a fresh manifest, explicit child
  selection, an exact observation digest, and a separate literal
  external-origin acknowledgment.
- **Why confirmation would normally be needed:** This favors safety over writer
  throughput and creates durable private operational history.
- **Why this is preferable:** A crash after network invocation cannot be made
  safely retryable when provider causality and idempotency are unknown.
- **If later rejected:** Any alternative must preserve atomic cross-process
  consumption, pre-dispatch evidence, non-dispatching reconcile, per-child crash
  recovery, and no automatic resend.

## 8. Anti-rollback, corruption, and lifecycle

- **Decision:** Use `CURRENT` generations plus an independent `AUTHORITY`
  latest-root anchor. Restore only an exact latest self-contained backup.
  Quarantine corruption and permanently block mutation after an unknown-state
  reset; whole-parent/APFS/VM/system-image rollback is unsupported and locally
  undetectable. Bound state, reserve reconciliation capacity, and require
  crash-safe checkpoints/GC/archive or clean epoch rotation. Resolve one
  canonical production state parent from the effective-user account record,
  with exact lock/AUTHORITY/epoch/recovery children and no override or silent
  legacy selection. Acquire its one lock before probing only the finite
  versioned three-root/eight-marker transition-evidence catalog, including a
  migrations-only or unreadable INTENT marker. Keep non-network inspection and
  exact-digest quarantine/reset reachable on detected evidence; migrate only
  one structurally valid cataloged lineage into an otherwise empty canonical
  parent through a crash-safe copy-validate-activate-retire flow after acquiring
  its compatible source lock and requiring explicit acknowledgment that legacy
  writer processes/packages are retired. Fresh start and each durable INTENT
  resume phase have separate eligibility; source-lock retirement is last and a
  post-retirement retry never recreates it. Inspection exposes the closed
  pending-migration digest/root/phase tuple so cold handoff resumes by confirmed
  INTENT digest without reconstructing original inputs. Quarantine acquires every compatible
  source lock or, for an incompatible/unreadable lock only, requires explicit
  source-quiescence acknowledgment plus identical full pre/post-copy scans.
  After permanently blocked reset, only the closed non-dispatching receipt,
  clock, checkpoint, backup, and archive maintenance set remains available
  while every preserved candidate exactly matches the quarantine seal; every
  path repeats a complete all-root scan immediately before publishing output.
  Candidate drift is not terminal: a new inspection can authorize only the
  `post-reset-candidate-drift` replacement-seal transition, which links the
  prior seal and latest committed maintenance root; exact-current-seal re-reset
  carries the whole seal chain and maintenance history into another permanently
  blocked epoch. This cycle restores only maintenance access and can never
  restore mutation authority.
  Multiple,
  canonical-plus-legacy, corrupt, or unknown candidates are quarantine-only;
  uncataloged locations are outside local detection. Quarantine is a sealed,
  digest-bound, crash-recoverable, irreversible authority transition requiring
  literal permanent-disable acknowledgment; reset remains permanently
  mutation-blocking.
  Destructive archive compaction requires a preceding immutable archive plan
  and exact digest confirmation.
- **Why confirmation would normally be needed:** The fixed state path,
  two-phase archives, permanent blocking, and unsupported backup boundary
  affect upgrades, operator workflow, storage, and availability.
- **Why this is preferable:** Restoring availability must not falsely erase a
  possibly dispatched mutation or re-enable an old plan.
- **If later rejected:** Add an independently monotonic external authority with
  outage, retention, privacy, restore, and adversarial rollback semantics, or
  redesign legacy migration/quarantine around an enforceable external freeze
  service; update the command grammar, phase model, maintenance allowlist,
  replacement-seal/maintenance-root authority schema, packaging gates, crash
  fixtures, and security review before relaxing these choices.

## 9. Output, observability, and secret handling

- **Decision:** Emit one JSON document on stdout and redacted diagnostics on
  stderr; use atomic `--output` when parseable delivery is required. Exclude
  bodies, headers, names, report rows, secrets, and free-form audit text from
  logs and state. Persist only bounded non-secret identifiers, digests, outcome
  axes, and observations whose causal origin is always `unknown`. Use a closed
  discriminated JSON result union with separate apply, rollback, lifecycle,
  utility, and pre-result error schemas and exhaustive action enums.
- **Why confirmation would normally be needed:** Operators may want verbose
  payload logs or embedded change-ticket reasons.
- **Why this is preferable:** Marketing payloads and arbitrary text can contain
  credentials, personal data, or commercially sensitive data.
- **If later rejected:** Add a typed bounded external-reference field or a
  separately classified support-bundle design with retention and leak tests.

## 10. Compatibility and readiness gates

- **Decision:** Remove the existing unqualified executable in slice one; ship
  no compatibility shim, symlink, alias, wrapper, or deprecation route. The
  normative annex provides the exhaustive command/flag grammar for exactly the
  reader and writer products; CLI help, README, tests, and packaging may not
  introduce extra routes. Framework acceptance does not equal feature readiness: all nine
  operations must have complete two-reviewer official evidence, contract tests,
  approved-app permission checks, safe sandbox verification, and zero
  unresolved high/medium findings before production-ready status.
- **Why confirmation would normally be needed:** Removing the current binary or
  holding every endpoint disabled affects release timing and scripts.
- **Why this is preferable:** A closed two-product surface is implementable and
  testable without an underspecified third route or accidental writer authority.
- **If later rejected:** Add a separately reviewed exhaustive read-only shim
  grammar, state isolation, deprecation date, packaging behavior, and negative
  mutation-route tests before restoring the product.

## 11. Ambiguous mutation recovery

- **Decision:** Provider-unknown, rejected-plus-desired, mixed/divergent, and
  other contradictory post-dispatch observations are never rollback-eligible.
  An operator may only close a fully observed intact ambiguity through exact
  plan/observation digests and explicit permanent-resource-disable
  acknowledgment. Closure makes affected resources permanently non-dispatching
  in the lineage and clears only that claim's global block.
- **Why confirmation would normally be needed:** Permanently disabling mutation
  for affected resources sacrifices automation and may require manual TikTok
  operations.
- **Why this is preferable:** TikTok does not provide evidenced mutation
  idempotency, compare-and-set, rejection atomicity, or causal readback; a local
  rollback could reverse an unrelated external change.
- **If later rejected:** Add a separately reviewed external authoritative
  adjudication mechanism that can establish mutation ownership and monotonic
  replay state; do not weaken the local acknowledgment or tombstone rules.

## Open questions deferred to evidence gates

- Which approved-app tier, endpoint limits, scopes, and advertiser grants apply
  to the eventual sandbox profile?
- Does current endpoint-specific official evidence introduce conditional
  mutation, idempotency, or stronger rejection atomicity?
- Which report dimension/metric combinations and attribution semantics are
  approved for the first production catalog revision?

These questions do not block design-author completion because every affected
operation remains disabled until the evidence gate answers them.

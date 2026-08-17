# Pending TikTok Business Gateway Decisions

**Status:** Historical pre-implementation questions; non-normative

## 1. Initial API surface

**Decision:** Pin Marketing API v1.3. Propose authorized advertisers,
advertiser details, manual campaigns, ad groups, ads, and bounded synchronous
integrated reports, but keep every operation disabled until its versioned
official-evidence entry is complete and independently reviewed. Exclude Smart+,
GMV Max, async reports, Organic API, and all other product families.

**Why confirmation would normally be needed:** Product priorities may favor
newer automated-campaign families or a different reporting workflow.

**Why this provisional choice is preferable:** It provides the smallest useful
ads foundation backed by the current official endpoint catalog while avoiding
deprecated and materially more complex campaign types.

**If the user disagrees:** Amend the evidence matrix and acceptance criteria,
add exact official endpoint/permission/version evidence and risk controls, then
obtain a new design review before implementation planning.

## 2. Reader and writer deployment boundary

**Decision:** Provide separate reader and writer executables, separate reader
and writer client modules, and a non-dispatching shared-support module. Writer
depends on reader only for catalog-declared safety reads; reader never depends
on writer.

**Why confirmation would normally be needed:** Multiple binaries affect
packaging, release scripts, documentation, and installation ergonomics.

**Why this provisional choice is preferable:** It gives a reviewable
least-privilege boundary, preserves shared non-network primitives, and prevents
the reader binary from linking or constructing writer routes.

**If the user disagrees:** A single binary would require an equivalent hard
capability boundary, separate entry paths/profiles, negative linkage tests, and
renewed security review; do not collapse to a runtime flag alone.

## 3. First writer allowlist

**Decision:** Propose only plan/apply status changes for manual campaigns, ad
groups, and ads. Apply uses a durable atomic single-use claim, fsynced
pre-dispatch journal, writer-wide dispatch serialization, exactly one one-shot
transport invocation, mandatory per-resource readback for every dispatched
outcome, and no claim of provider compare-and-set, batch
atomicity, or mutation causality. Provider outcome and observed state remain
independent. Defer create, general update, budget/bid, targeting, creative,
audience, account, billing, and permission operations.

**Why confirmation would normally be needed:** The intended business workflow
may require full campaign creation or budget automation.

**Why this provisional choice is preferable:** Status changes are bounded,
readable before and after application, and reversible through another explicit
plan. They establish the writer safety foundation without exposing spend and
targeting configuration broadly.

**If the user disagrees:** Add each desired mutation as a separately evidenced
allowlist entry with typed validation, idempotency/ambiguity analysis,
plan/apply semantics, rollback limits, sandbox tests, and independent review.

## 4. Credential lifecycle

**Decision:** Slice one consumes an externally provisioned Marketing API
long-term token from a profile-named environment variable. It does not build
authorization URLs, receive callbacks, exchange codes, refresh, revoke, or
store app secrets. `reader auth status` is local-only: it validates profile and
required environment-reference presence without constructing transport,
performing provider discovery, or claiming provider authorization. It is not
one of the six reader or nine total catalog operations. Neither binary exposes
a generic network `auth verify`; provider authorization is exercised only by a
catalog-declared operation, including writer safety-read workflows.

**Why confirmation would normally be needed:** Some users may expect an
interactive login and durable local token storage.

**Why this provisional choice is preferable:** TikTok's callback must be
internet-reachable, token contracts differ across API families, and local auth
automation would materially expand secret-handling and callback security scope.
Keeping status local also makes the token-only smoke command unambiguous and
prevents undocumented advertiser-discovery behavior.

**If the user disagrees:** Create a separate auth-lifecycle design covering
state validation, callback ownership, code input, app-secret storage, token
family/expiry, refresh/revocation, Keychain storage, recovery, and redaction.

## 5. Pagination policy

**Decision:** Fetch one page by default. Allow sequential `--all-pages` only
with an explicit `--max-pages` of at most 100 and cataloged cumulative item,
encoded-byte, response, JSON-structure, decoded-memory, envelope, and working-
set bounds enforced at page boundaries. Do
not provide a caller-selected mid-page item cap or cross-invocation resume in
slice one, and never claim snapshot consistency. After at least one successful
page, every later-page provider, authentication, throttle, transport, timeout,
cancellation, or protocol failure returns one retained-prefix partial envelope,
exit 7, a closed reason/action, and no item from the failed page; before the
first page, ordinary error exits apply and stdout is empty. Metadata-proven zero
results and explicitly requested pages beyond the result boundary are valid
empty exit-0 results. Any valid report throttle warning, including on the first
or nominally final page, retains that page but returns
`throttleWarning`/`retryLater` partial output and exit 7.

**Why confirmation would normally be needed:** Consumers may prefer automatic
full traversal or streaming materialization.

**Why this provisional choice is preferable:** It bounds cost, memory, time,
rate-limit pressure, and accidental report expansion without pretending that
page-number pagination can resume a partial page or preserve a changing
provider snapshot.

**If the user disagrees:** Specify the required output/materialization model,
hard byte/item/time caps, cancellation/resume contract, and rate-limit impact,
then review before implementation.

## 6. Local rate policy

**Decision:** Record TikTok's current official Basic app defaults separately
from the actual approved-app tier. Each CLI process allows one in-flight read
per profile and at most two request starts per second. Slice-one configuration
can only lower these values; processes do not share a bucket.

**Why confirmation would normally be needed:** Throughput requirements and the
approved app's limits may justify different settings.

**Why this provisional choice is preferable:** The current official rate page
documents Basic defaults of 10 QPS, 600 QPM, and 864,000 QPD, but the approved
app tier and endpoint/advertiser limits can differ. One in-flight request and
two starts per second are conservative without adding a second interprocess
state system.

**If the user disagrees:** Record current official or app-console evidence,
define per-operation/account/application buckets, update deterministic retry
tests, and review the new ceiling. A profile-wide cap additionally requires an
owner-only interprocess limiter and stale-lock recovery design.

## 7. Compatibility executable

**Decision:** The existing `tiktok-business-gateway` executable may remain only
as a temporary read-only compatibility shim with a deprecation warning. It may
not link or instantiate the writer client.

**Why confirmation would normally be needed:** Removing or retaining the
original product changes user scripts and Homebrew packaging.

**Why this provisional choice is preferable:** A read-only shim avoids an
immediate breaking install while preserving the capability boundary.

**If the user disagrees:** Either remove the product in a documented breaking
release or define a dated deprecation window; never make it a hidden
reader/writer multiplexing entry point.

## 8. Durable writer recovery state

**Decision:** Store immutable claims and durable apply journals in the current
user's Application Support directory. Make claim, active-child `dispatching`,
provider outcome, observation, and receipt separate authoritative `CURRENT`
generation commits. The complete plan digest is permanently single-use once
claimed; every child has durable state; restart/reconcile never dispatches a
claimed or unfinished child; and every untouched remainder needs a fresh plan.
Missing or corrupt journal evidence after claim publication is always unknown
and blocks new mutations rather than proving no dispatch. Maintain an
independent latest-authority anchor; backups are self-contained and can restore
in place only when their complete authority tuple exactly matches that anchor,
so an older valid backup cannot roll claims backward. The guarantee covers only
supported in-band state lifecycle. Whole-parent, APFS, VM, system-image, and
copied-tree rollback can restore CURRENT and AUTHORITY together, is unsupported
and locally undetectable, and when known or suspected permanently blocks the
lineage. Supporting it requires a separately reviewed independently monotonic
external anchor.

**Why confirmation would normally be needed:** Durable private state affects
local storage, retention, backup, and operational recovery expectations.

**Why this provisional choice is preferable:** A receipt written only after
dispatch cannot survive crashes or output failures. A fsynced pre-dispatch
journal provides a recovery path and prevents concurrent or replayed apply;
independent latest-root anchoring prevents restore from erasing later claims.
Stating the whole-parent boundary avoids claiming protection the local
durability domain cannot provide.

**If the user disagrees:** Any alternative must still provide atomic cross-
process single-use claims, crash-safe pre-dispatch evidence, per-resource
reconciliation, schema migration, and no automatic mutation resend.
Supporting whole-parent restore additionally requires an independent monotonic
ledger/counter, lifecycle and outage semantics, and rollback simulation review.

## 9. Writer audit metadata

**Decision:** Writer request and plan schemas contain no free-form reason,
comment, label, or audit-reference field. The generated plan ID is correlated
with external change-management records.

**Why confirmation would normally be needed:** Operators may want business
context embedded directly in plan artifacts.

**Why this provisional choice is preferable:** Arbitrary text can contain
credentials or personal data, defeating the design's testable no-secret and
minimal-data guarantees.

**If the user disagrees:** Design a separately typed, bounded identifier with
classification, validation, redaction, retention, and leak tests before adding
it to writer artifacts.

## 10. Trust-bearing file policy

**Decision:** Config and every writer input/state artifact must be owned by the
effective user, not group/other writable, and validated on a no-follow open
descriptor. All trust-bearing JSON rejects duplicate keys at every depth before
typed decoding; bounded canonical profile, advertiser, operation, and resource
identities must be unique, and conflicts reject the whole input before profile
selection or secrets. Reader-only request fixtures may be foreign-owned only
when non-writable by group/others and descriptor-validated.

**Why confirmation would normally be needed:** Strict ownership rules can make
team-shared configuration less convenient.

**Why this provisional choice is preferable:** These files control account and
mutation authorization; descriptor validation avoids symlink and check/open
races. The reader exception retains safe version-controlled fixtures.

**If the user disagrees:** Define an explicit trusted-group model, immutable
deployment mechanism, or signed configuration format and obtain renewed
security review; do not weaken checks implicitly.

## 11. Plan integrity and local trust boundary

**Decision:** Hash every plan field except the digest itself and use that full
digest, not plan ID, as replay identity. Bind a domain-separated canonical
digest of every non-secret security-relevant profile field, including credential
reference names, to the plan. Secret-value rotation behind the same reference
is allowed; changing a reference or authorization field invalidates an
unclaimed plan. Promise single-use protection only for an unmodified gateway-
generated plan across cooperating processes sharing the trusted effective
user's state directory; do not add signing/HMAC in slice one.
Plan and rollback issuance also commit a durable wall-clock high-water,
system-wide continuous tick, and boot-session identifier. Backward clocks block
execution, reboot invalidates unclaimed artifacts, and same-boot continuous or
wall expiry is ten minutes; no operator override lowers the high-water.

**Why confirmation would normally be needed:** A stronger hostile-local-user
threat model would require authenticated plan issuance and secret/key lifecycle.

**Why this provisional choice is preferable:** It binds all security-relevant
plan meaning, removes editable plan ID from replay authority, and states the
actual local trust boundary without introducing another credential system.

**If the user disagrees:** Design signed plan issuance, verification-key
distribution, rotation, recovery, and migration; then re-review claim identity
and every automation interface before implementation.

## 12. Observation causality and rollback acknowledgment

**Decision:** Treat every post-dispatch read as an immutable observation with
unknown causal origin. Require the latest observation digest as an explicit
external-origin-risk acknowledgment before rollback planning or execution.
Rollback reconciliation is phase one: it only commits and emits a new aggregate
observation digest. A separate locked, non-network `rollback-acknowledge`
command is phase two: exact acknowledgment of the latest usable digest commits
an idempotent terminal receipt and clears only that rollback aggregate's block.
Reconcile alone never terminalizes; stale acknowledgment never changes state;
resume requires the current acknowledged receipt.

**Why confirmation would normally be needed:** Operators may prefer a simpler
rollback command or may accept different concurrency risks.

**Why this provisional choice is preferable:** Provider reads cannot prove who
caused a status or whether a transient mutation occurred. The acknowledgment
prevents automation from presenting an unsafe causal inference as fact, while
the explicit second phase gives every ambiguous rollback a bounded, usable
operator-review path.

**If the user disagrees:** Enable simpler rollback only after official evidence
and implementation prove a provider mutation token or audit event that can be
causally matched; otherwise preserve the warning and manual review boundary.

## 13. Durable multi-child rollback execution

**Decision:** Provide a canonical, hashed, ten-minute rollback manifest and
explicit execute, reconcile, and resume commands backed by an owner-only
aggregate journal. Require an explicit bounded selection file with 1...5 unique
resource IDs; there is no implicit all-eligible default. Bind epoch, parent
claim, the canonical selected-child observation acknowledgment, authorization
fingerprint, catalog/recovery revisions, and ordered children. A non-network
locked inspect command emits the selection acknowledgment digest before plan.
Execute uses the same authoritative per-child commits and safety limits as
apply. Reconcile never dispatches or terminalizes; the separate acknowledgment
command commits the latest reviewed observation digest before resume. Resume
only emits a fresh manifest for an old manifest's untouched remainder after
started children are reconciled and acknowledged; it never continues dispatch
under the consumed digest.

**Why confirmation would normally be needed:** This adds CLI surface and durable
private state, while some operators may prefer manual child-plan application.

**Why this provisional choice is preferable:** A manifest containing several
child plans otherwise has no crash-safe consumption contract. Explicit durable
orchestration makes partial reversal and recovery visible and deterministic.

**If the user disagrees:** Remove aggregate execution and document a strictly
manual one-child-at-a-time contract with equivalent digest confirmation,
observation acknowledgment, stop conditions, and operator-maintained recovery
records; re-review automation compatibility.

## 14. Writer-state transaction serialization

**Decision:** Serialize every writer-state reader or mutator for the effective
user with one validated crash-releasing OS transaction lock: plan, apply,
reconcile, rollback including acknowledgment, initialize, inspect, backup, restore, archive, epoch
rotation, quarantine, reset, and migration. Hold it across network work and
every atomic `CURRENT` generation commit. Each claim, active-child marker,
outcome, observation, and receipt becomes separately authoritative and is read
back before its dependent external action. Unresolved or corrupt state blocks
all new dispatch until reconciled or manually inspected. Acquisition is
nonblocking and cancellable with a default and maximum 2,000-ms continuous-time
deadline; cancellation or contention returns sanitized exit 8/`retryLater`
without secrets, network, claim, or state mutation. The gateway never removes
or diagnoses a live/suspended holder; OS death releases the lock.

**Why confirmation would normally be needed:** This deliberately reduces
writer throughput and allows one unresolved operation to pause unrelated
profiles or advertisers.

**Why this provisional choice is preferable:** It eliminates overlap races
between dispatch, reconciliation, snapshots, epoch replacement, restoration,
and migration without relying on a complex lock graph or provider compare-and-
set support. OS process death releases ownership without stale-lock deletion.
The fixed bound also preserves the CLI's operation-time guarantees under a
suspended holder or rapid contention.

**If the user disagrees:** Design canonical profile/advertiser/resource lock
sets, total lock ordering, partial-overlap detection, durable stale-lock
recovery, and equivalent ambiguous-state blocking before allowing concurrency.

## 15. One-shot mutation transport

**Decision:** Reject all redirects and replay-capable challenges, use a one-use
mutation body, disable connectivity waiting, cookies, caches, credentials, and
client retries, and classify any requested replay as possibly sent. A transport
failure proven before request dispatch commits the one legal proven-unsent
tuple, which is expressly outside attempted-dispatch invariants and maps only
to exit 8/`newPlan`.

**Why confirmation would normally be needed:** Some environments may rely on
redirects, proxy authentication, or automatic connectivity recovery.

**Why this provisional choice is preferable:** Those conveniences can resend a
status mutation and violate the single-dispatch contract. Explicit ambiguity
and reconciliation are safer than transparent transport recovery.

**If the user disagrees:** Provide provider and runtime evidence for each
allowed transport behavior, prove the mutation cannot be resent or credentials
redirected, and repeat adversarial transport review and local-server tests.

## 16. Production-readiness minimum

**Decision:** Permit an all-disabled catalog to pass framework-design review,
but do not call the feature delivered until all six proposed reader operations
and all three status writers are evidence-complete, independently reviewed,
contract-tested, permission-verified, sandbox-tested, and enabled.

**Why confirmation would normally be needed:** Product delivery may prefer a
smaller staged subset, such as reader-only access or one resource family.

**Why this provisional choice is preferable:** It prevents a vacuous success
claim while preserving fail-closed implementation and review before dynamic
official endpoint contracts can be substantiated.

**If the user disagrees:** Define a named partial milestone with its exact
minimum operation IDs and user-visible limitations; do not label that milestone
the complete TikTok Business Gateway feature.

## 17. Irrecoverable writer-state recovery epoch

**Decision:** Bind plans and rollback manifests to a writer-state epoch. If the
latest anchored state cannot be restored exactly, preserve and seal it and allow
reset only into a permanently mutation-blocked epoch. Carry all known resource
and advertiser blocks forward and add a global block when prior state cannot be
fully enumerated. The authority disposition can move from enabled to blocked
but never back; acknowledgment, reset, restore, or clean epoch rotation cannot
re-enable mutation in slice one.

**Why confirmation would normally be needed:** Permanent mutation disablement
may require a new deployment or separately designed adjudication service and
therefore sacrifices local writer availability after irrecoverable corruption.

**Why this provisional choice is preferable:** Without provider idempotency or
causal evidence, a fresh dispatch-capable epoch could repeat an unknown prior
mutation. Permanent blocking preserves the only conservative safety boundary
when exact replay evidence is unavailable.

**If the user disagrees:** Design and independently review an authoritative
external adjudication or replicated journal that can prove the exact latest
claim/resource state. Never restore mutation authority through a local
acknowledgment, epoch change, or deletion of unknown evidence.

## 18. Segmented no-copy reader output

**Decision:** Retain canonical item segments once and stream the validated
prefix, segments, separators, and suffix without allocating a second complete
document. Catalog and test the bounded output-write buffer. Exactly-one-complete
JSON is guaranteed only after a successful stdout write; a write failure may
leave a truncated prefix and never emits replacement JSON. Every data command
offers owner-only same-directory atomic `--output` delivery for consumers that
require parseable failure semantics.

**Why confirmation would normally be needed:** This constrains encoder and
stdout/output-file implementation choices and may be less convenient than
building one final in-memory data value.

**Why this provisional choice is preferable:** It makes the documented peak-
memory bound true for large traversals and prevents the final encoded document
from duplicating the retained payload in memory.

**If the user disagrees:** Add the entire maximum final document as a second
simultaneous allocation, lower traversal limits accordingly, update manifest
bounds, and repeat adversarial peak-memory verification.

## 19. Authorized-advertiser app secret

**Decision:** Keep `advertisers.list` as a proposed reader operation, but give
it optional profile fields for a non-secret app ID and an app-secret environment
variable reference. Resolve the app secret only for this operation, never log
an absolute URL/query, and use a new single-task ephemeral session with cache,
cookies, credential storage, redirects, proxy persistence, task-metric history,
and reuse disabled. Leave the operation disabled until raw/encoded secret tests
prove no secret reaches diagnostics, application-container files, URL caches,
cookie/credential stores, proxy/challenge callbacks, task metrics, or crash
diagnostics before or after session invalidation.

**Why confirmation would normally be needed:** TikTok's official GET requires
an app secret in the query in addition to `Access-Token`; some users may prefer
to exclude the operation rather than accept that runtime handling surface.

**Why this provisional choice is preferable:** Authorized-account discovery is
useful and officially supported, while operation-local secret resolution and a
hard nonpersistence release gate prevent every other reader from requiring the
app secret or a default networking subsystem from retaining it.

**If the user disagrees:** Remove `advertisers.list`, its profile fields, and
its readiness requirement; rely on configured advertiser allowlists plus
`advertisers.get`, then repeat capability and documentation review.

## 20. Single-resource status dispatch

**Decision:** Although TikTok documents 1...20 IDs for campaign, ad-group, and
ad status updates, send exactly one resource per request. Permit only `ENABLE`
and `DISABLE`; force `allow_partial_success=false` for ad groups and omit ACO,
R&F, `DELETE`, and campaign postback-window inputs. Stop a multi-child apply at
the first non-success or uncertain child; reconcile dispatched children and
require a fresh plan for every undispatched remainder rather than forward
resuming the consumed plan. Cap a plan at five children and 256 KiB, require a
35-second remaining budget before each child, and bound the post-claim apply to
180 seconds with per-child mutation, readback, and finalization budgets. Plans
must be uniformly actionable or uniformly already-desired; mixed requests fail
without a plan. Applying an all-no-op plan commits a single-use no-op receipt
but cannot construct or invoke mutation transport.

**Why confirmation would normally be needed:** One-resource requests reduce
throughput and consume more rate-limit budget than provider-sized batches;
rejecting mixed plans may require callers to partition ordinary requests.

**Why this provisional choice is preferable:** It makes provider outcome and
readback attributable to one resource, avoids documented partial-success mode,
and contains ambiguity when no provider conditional mutation or rejection
atomicity is established.

**If the user disagrees:** Design typed per-resource batch results, partial and
unknown-outcome reconciliation, batch rejection semantics, rate accounting,
and crash recovery from official evidence, then repeat adversarial review.

## 21. Bounded writer-state lifecycle

**Decision:** Cap regular writer state at 512 MiB and the complete root at 576
MiB, with 1,000 unclaimed issuance records, 50,000 claim digests, 4 MiB per
journal, 16 inline observation rounds, 80 inline observation records per plan,
and a 64 MiB recovery reserve. Warn at
70%, reject new plan/apply claims at 80%, and
at 95% permit only bounded reconciliation/finalization network work that first
proves reserve for its response and two commits. When inline observation limits
are reached, atomically externalize immutable observations to a verified,
bounded owner-only recovery segment and retain a required digest anchor plus the
latest full observation. Compact terminal journals to exact replay tombstones;
provide digest-verified archive and clean epoch rotation without requiring reset
merely to regain reconciliation capacity.
Archival commits a self-contained checkpoint and advances both CURRENT and the
independent AUTHORITY anchor before garbage collection. Only unreferenced
pre-checkpoint generation files may then be deleted in fsynced bounded batches;
physical bytes are released only after durable unlink.

**Why confirmation would normally be needed:** Capacity ceilings, compaction,
archive locations, and epoch rotation affect operational retention, audit, and
availability expectations.

**Why this provisional choice is preferable:** Hard bounds prevent ordinary
retention from exhausting disk and corrupting writer-wide state. Exact digest
tombstones preserve replay rejection, while clean epoch rotation invalidates
all old plans before releasing active capacity. Anchored self-contained
checkpoints make physical garbage collection crash-safe without requiring the
deleted ancestor chain at startup.

**If the user disagrees:** Specify larger or externally managed storage plus
equivalent hard quotas, recovery reserve, exact replay indexing, archival
integrity, privacy controls, and disk-full behavior, then repeat durability and
security review before implementation.

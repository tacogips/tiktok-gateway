# TikTok Business Gateway Session Handover

**Handover date:** 2026-08-16 (Asia/Tokyo)

**Repository:** the repository root

## Current outcome

The Swift gateway implementation is locally complete for its bounded Marketing
API v1.3 surface. TikTok developer registration is complete, and the
`TikTok Business Gateway` app has been submitted through TikTok API for
Business. TikTok currently reports the application as **Pending**.

The portal currently displays `--` for both App ID and Secret. Therefore no
TikTok application credential or access token has been stored in kinko, and an
authenticated live API smoke test has not yet been possible. TikTok's portal
states that review may take up to three days.

## TikTok portal state

- App name: `TikTok Business Gateway`
- Verification status: `Pending`
- App ID: not issued (`--` in the portal)
- Secret: not issued (`--` in the portal)
- Advertiser redirect URL: `https://konjac-note.com/`
- TikTok account holder redirect URL: `https://konjac-note.com/`
- Test-account identity requested by the user:
  `taco-dev-sandbox@mutvar.com`
- The browser session appeared logged in under the TikTok display identity
  `mutvar0815`. Do not assume this proves that the requested email identity,
  advertiser grant, and eventual API authorization are the same; confirm them
  through the approved app and authorized-advertiser API response.
- No payment information was requested during developer registration or app
  submission. If TikTok later requires payment details, the user will enter
  them personally.

The submitted English app description is:

> A developer gateway for using TikTok API for Business across my own
> applications, advertising, analytics, creative workflows, measurement,
> audiences, commerce, TikTok Shop, and related account operations. It will
> support ads for applications I develop and future e-commerce initiatives.
> Access will be used only for owned or explicitly authorized accounts, with
> local credential protection, account allowlists, auditability, and separate
> read/write controls.

The generated 512x512 PNG submitted as the app logo is retained at:

`packaging/assets/tiktok-business-gateway-app-icon.png`

## Requested portal permissions

Every permission category visible in the creation form was selected as
`All`, including:

- Ad Account, Ads, Audience, Reporting, Measurement, and Creative Management
- App, Pixel, DPA Catalog, Reach & Frequency, and Lead Management
- TikTok Creator Marketplace, TikTok Creator, Ad Comments, and TikTok Business
  Plugin
- Automated Rules, TikTok Accounts, Onsite Commerce Store, and Offline Events
- Ad Diagnosis, Mentions, CRM Events, Business Recommendation, and CTX Events
- Brand Safety, Partner Insights, Payment Portfolio, and Custom Conversions
- Minis and Business Verification

TikTok may reject or narrow this unusually broad request or ask for additional
justification. Preserve the user's explicit direction to request all APIs, but
do not claim approval until the portal shows the granted scopes.

## Important scope distinction

The portal requests all available permission categories for present and future
use. The repository does **not** yet implement every TikTok API.

The current Swift code implements a fixed nine-operation Marketing API v1.3
surface:

- Reader: authorized advertisers, advertiser details, campaigns, ad groups,
  ads, and BASIC synchronous integrated reports
- Writer: single-resource `ENABLE` or `DISABLE` for manual campaigns, manual
  non-Reach-and-Frequency ad groups, and manual non-ACO ads

Reader and writer clients, core modules, and executables are structurally
separate. The reader product does not link mutation code. Creation, deletion,
budget, bid, targeting, creative mutation, commerce, payment, and most other
approved-scope operations remain unimplemented. Expanding those APIs requires
new official endpoint evidence, typed request/response contracts, safety
controls, and tests rather than adding arbitrary URL/body passthrough.

## Implementation and verification completed

Relevant targets and entry points:

- `Sources/TikTokBusinessGatewayShared/`
- `Sources/TikTokBusinessGatewayReaderCore/`
- `Sources/TikTokBusinessGatewayWriterCore/`
- `Sources/TikTokBusinessGatewayReader/main.swift`
- `Sources/TikTokBusinessGatewayWriter/main.swift`

The implementation includes fixed operation catalogs, allowlisted profiles and
advertisers, environment-based credential resolution, redaction, strict JSON,
bounded responses, redirect rejection, safe-read retry policy, conservative
writer dispatch behavior, and typed TikTok envelopes/models.

The previous session completed these local checks successfully:

- Full Swift test suite: 49 tests passed
- SwiftLint: passed with zero findings
- Swift formatting check: passed
- Debug and release builds: passed
- Reader artifact boundary and release-safety checks: passed
- Unauthenticated HTTPS reachability to the fixed TikTok API origin: passed

No authenticated provider test has passed yet because TikTok has not issued the
App ID or Secret. No live writer mutation has been attempted.

Useful commands for revalidation:

```bash
mise install
mise run lint
mise run test
mise run build
scripts/check-exported-api.sh
scripts/check-reader-artifact-boundary.sh
scripts/check-release-builder-safety.sh
scripts/check-official-https.sh
swift run tiktok-business-gateway-reader --help
swift run tiktok-business-gateway-writer --help
```

## Credential and kinko state

- kinko binary observed at `/opt/homebrew/bin/kinko`.
- The default kinko vault was verified unlocked on 2026-08-16.
- No TikTok credential values have been obtained or saved.
- A masked `kinko show` presence check found none of the planned
  `TIKTOK_SANDBOX_*` keys. Existing unrelated key names were not copied into
  this handover.
- Never print, document, commit, or place secrets in shell arguments, process
  listings, logs, fixtures, or the non-secret profile JSON.

Proposed kinko key names, once corresponding values genuinely exist:

- `TIKTOK_SANDBOX_APP_ID`
- `TIKTOK_SANDBOX_APP_SECRET`
- `TIKTOK_SANDBOX_READER_ACCESS_TOKEN`
- `TIKTOK_SANDBOX_WRITER_ACCESS_TOKEN`
- A refresh-token key only if TikTok's approved authorization flow actually
  returns one and its lifecycle is explicitly designed

Use kinko's interactive/standard-input secret entry so values are not embedded
in command arguments. Verify only key presence and successful injection, never
echo the values.

Do not create placeholder values for missing TikTok credentials. The next
session must first verify that TikTok has issued the corresponding value, then
store it immediately and verify only its masked presence.

## Start the next session

Invoke the installed user skill and point it at this record:

```text
$apply-tiktok-business-api Continue the pending TikTok Business Gateway app
review, credential storage, OAuth authorization, and authenticated smoke tests
using design-docs/session-handover-2026-08-16.md.
```

Reusable skill location:

`$CODEX_HOME/skills/apply-tiktok-business-api/SKILL.md`

At handover time the correct first action remains a read-only portal status
check. Do not start a new app application.

## Exact next-session checklist

1. Open `https://business-api.tiktok.com/portal/apps` in the existing signed-in
   browser session and inspect `TikTok Business Gateway`.
2. If status remains `Pending`, record that result and wait; credentials and
   authenticated tests remain blocked legitimately.
3. If rejected or additional information is requested, capture the non-secret
   review reason, update the form/documentation, and obtain user input for any
   business, identity, legal, or payment information.
4. If approved, inspect the actually granted scopes and record any difference
   from the requested `All` categories.
5. Obtain the App ID and Secret without exposing their values. Store them in
   kinko under stable names and verify presence only.
6. Re-check current official TikTok OAuth documentation before authorization;
   endpoint paths, parameters, token lifetime, and callback query names are
   time-sensitive. The registered redirect must exactly match
   `https://konjac-note.com/`.
7. Confirm that `https://konjac-note.com/` preserves or safely hands off the
   OAuth callback query and does not log authorization codes. If it does not,
   design and deploy a dedicated HTTPS callback path, then update the exact
   registered URLs before OAuth.
8. Immediately before clicking TikTok's final account authorization control,
   obtain action-time user confirmation because it grants persistent access.
9. Exchange the authorization code without exposing the code, app secret, or
   tokens. Store returned tokens in kinko.
10. Call the authorized-advertisers reader operation and confirm the advertiser
    belongs to the intended sandbox/test identity. Do not infer this from the
    Ads Manager browser URL alone.
11. Create the non-secret reader/writer profiles at
    `~/.config/tiktok-business-gateway/profiles.json`, using only kinko-injected
    environment-variable names and the confirmed advertiser ID.
12. Run authenticated read-only smoke checks first: auth status, authorized
    advertisers, advertiser details, one bounded list request, and a small
    BASIC report if the account contains suitable data.
13. Attempt a writer smoke test only after the user explicitly confirms a
    non-serving sandbox resource, its current state, and the intended no-op or
    reversible status. Never use a production-serving campaign merely to prove
    connectivity.
14. Update this handover, `README.md`, and the implementation plan with approval
    status, granted scopes, credential-presence verification, and sanitized
    smoke-test results. Do not record secret values or sensitive response data.

## Repository and git state

The repository had no initial tracked commit during this work; `git status`
showed the project tree as untracked. No commit, release, upload, signing,
notarization, or Homebrew publication was requested or performed. Preserve all
existing files as user work and inspect status before future edits.

## Primary local references

- `README.md`
- `design-docs/tiktok-business-gateway.md`
- `design-docs/tiktok-business-gateway-design.md`
- `design-docs/references/tiktok-marketing-api-v1.3-evidence.json`
- `impl-plans/tiktok-business-gateway.md`
- Sibling architectural reference:
  `../google-marketing-gateway`

The original research/design process used Riela. Continue using the applicable
Riela workflow for further API research, design changes, and implementation
planning when it is available in the next session.

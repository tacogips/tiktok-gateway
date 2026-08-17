# Command

## Status

Implemented practical reader/writer command surface. Executable `--help` output
is the authoritative grammar.

## Current CLI

```text
tiktok-business-gateway-reader <catalog|config|auth|advertisers|campaigns|adgroups|ads|reports> ...
tiktok-business-gateway-writer <catalog|config|campaigns|adgroups|ads> ...
```

Writer status updates require one advertiser ID, one resource ID,
`--resource-family MANUAL`, `ENABLE` or `DISABLE`, and an exact
`--confirm-status`. Unsupported campaign, Reach-and-Frequency ad-group, and ACO
ad families fail before credential resolution or transport. No generic
method/path/body or `DELETE` command exists. The durable
plan/apply/reconcile/state command surface from the historical design annex is
not implemented.

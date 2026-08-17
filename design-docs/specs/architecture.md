# Architecture

## Status

Implemented practical scope. Durable writer-state research is deferred.

## Overview

`tiktok-business-gateway` is a Swift Package Manager project with a shared
transport/configuration target, separate reader and writer libraries, separate
executables, tests, and release automation.

## Targets

- `TikTokBusinessGatewayShared`: catalog, configuration, credentials,
  redaction, envelope decoding, HTTPS transport, retries, and CLI support.
- `TikTokBusinessGatewayReaderCore`: typed read requests, models, pagination,
  synchronous reports, and reader CLI.
- `TikTokBusinessGatewayWriterCore`: one-resource status requests and writer
  CLI; it does not depend on ReaderCore.
- `TikTokBusinessGatewayReader` and `TikTokBusinessGatewayWriter`: thin
  executable entry points.
- Three matching test targets.

## Release Surfaces

- Reader product: `tiktok-business-gateway-reader`
- Writer product: `tiktok-business-gateway-writer`
- Homebrew automation remains a separate release workflow and was not invoked
  by this implementation.

#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

cd "$repo_root"
TIKTOK_BUSINESS_GATEWAY_RUN_HTTPS_INTEGRATION=1 \
  swift test --filter concreteTransportUsesPlatformTrustForOfficialHTTPS

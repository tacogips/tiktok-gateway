#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
reader_product="tiktok-business-gateway-reader"

cd "$repo_root"
swift build -c release --product "$reader_product" >/dev/null
binary_path="$(swift build -c release --product "$reader_product" --show-bin-path)/$reader_product"

for forbidden in \
  'campaigns.status.update' \
  'adgroups.status.update' \
  'ads.status.update' \
  '/campaign/status/update/' \
  '/adgroup/status/update/' \
  '/ad/status/update/' \
  'WriterRequestFactory' \
  'CampaignStatusBody' \
  'AdGroupStatusBody' \
  'AdStatusBody'
do
  if strings "$binary_path" | grep -F -- "$forbidden" >/dev/null; then
    printf 'reader release binary contains writer symbol or route: %s\n' "$forbidden" >&2
    exit 1
  fi
done

printf 'reader release artifact excludes writer routes and request builders\n'

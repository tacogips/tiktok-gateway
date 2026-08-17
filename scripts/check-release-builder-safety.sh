#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/tiktok-release-safety.XXXXXX")"

cleanup() {
  rm -rf -- "$temporary_root"
}
trap cleanup EXIT

mkdir -p \
  "$temporary_root/formula-release" \
  "$temporary_root/cask-release" \
  "$temporary_root/outside-formula" \
  "$temporary_root/outside-cask"
printf 'formula-safe\n' > "$temporary_root/outside-formula/sentinel"
printf 'cask-safe\n' > "$temporary_root/outside-cask/sentinel"
ln -s "$temporary_root/outside-formula" "$temporary_root/formula-release/work"
ln -s "$temporary_root/outside-cask" "$temporary_root/cask-release/work"

native_target="darwin-arm64"
if [[ "$(uname -m)" == "x86_64" ]]; then native_target="darwin-x64"; fi

if RELEASE_DIR="$temporary_root/formula-release" \
  "$repo_root/scripts/build-homebrew-release.sh" "$native_target" >/dev/null 2>&1
then
  printf 'formula builder accepted a symlinked work directory\n' >&2
  exit 1
fi
if CASK_RELEASE_DIR="$temporary_root/cask-release" \
  "$repo_root/scripts/build-homebrew-cask-release.sh" "$native_target" >/dev/null 2>&1
then
  printf 'cask builder accepted a symlinked work directory\n' >&2
  exit 1
fi

grep -Fx 'formula-safe' "$temporary_root/outside-formula/sentinel" >/dev/null
grep -Fx 'cask-safe' "$temporary_root/outside-cask/sentinel" >/dev/null
printf 'release builders reject symlinked work roots without external modification\n'

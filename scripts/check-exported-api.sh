#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/tiktok-business-gateway-api.XXXXXX")"

cleanup() {
  rm -rf -- "$temporary_root"
}
trap cleanup EXIT

cd "$repo_root"
binary_path="$(swift build --show-bin-path)"
module_path="$binary_path/Modules"

cat > "$temporary_root/transport-seam.swift" <<'SWIFT'
import Foundation
import TikTokBusinessGatewayShared

struct ExternalTransport: HTTPTransport {
  func send(_ request: HTTPRequest) async throws -> HTTPResponse {
    _ = request.url
    return HTTPResponse(statusCode: 418, body: Data())
  }
}
SWIFT

swiftc -typecheck -I "$module_path" "$temporary_root/transport-seam.swift"

cat > "$temporary_root/arbitrary-request.swift" <<'SWIFT'
import Foundation
import TikTokBusinessGatewayShared

let arbitraryRequest = HTTPRequest(
  method: HTTPMethod.post,
  url: URL(string: "https://business-api.tiktok.com/open_api/v1.3/arbitrary/")!,
  headers: ["Access-Token": "caller-selected"],
  body: Data("{}".utf8)
)
SWIFT

if swiftc -typecheck -I "$module_path" "$temporary_root/arbitrary-request.swift" \
  2> "$temporary_root/arbitrary-request.err"; then
  printf 'external caller unexpectedly constructed HTTPRequest\n' >&2
  exit 1
fi

if ! grep -Eq "inaccessible due to 'package' protection level|package access" \
  "$temporary_root/arbitrary-request.err"; then
  printf 'external HTTPRequest construction failed for an unexpected reason\n' >&2
  cat "$temporary_root/arbitrary-request.err" >&2
  exit 1
fi

printf 'exported API boundary passed\n'

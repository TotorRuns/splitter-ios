#!/usr/bin/env bash
# Rebuilds the vendored livesplit-core static libraries and Swift bindings.
# Usage: scripts/build-livesplit-core.sh [git-ref]   (default: the pinned commit)
set -euo pipefail
REF="${1:-428d1ea3281cab6a339e860a7068aa3cacb9d7ed}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${LIVESPLIT_CORE_DIR:-$ROOT/.build/livesplit-core-src}"

if [ ! -d "$WORK/.git" ]; then
  git clone https://github.com/LiveSplit/livesplit-core "$WORK"
fi
git -C "$WORK" fetch --depth 1 origin "$REF" 2>/dev/null || true
git -C "$WORK" checkout -q "$REF"

rustup target add aarch64-apple-ios >/dev/null
cd "$WORK"
# Keep local paths (home folder, cargo registry, checkout location) out of the published libraries.
export RUSTFLAGS="${RUSTFLAGS:-} --remap-path-prefix=$WORK=/livesplit-core --remap-path-prefix=$HOME/.cargo=/cargo --remap-path-prefix=$HOME/.rustup=/rustup"
# Only the static library is needed; the cdylib would need Apple's linker.
IPHONEOS_DEPLOYMENT_TARGET=17.0 cargo rustc --release -p livesplit-core-capi \
  --target aarch64-apple-ios --crate-type staticlib
cargo rustc --release -p livesplit-core-capi --crate-type staticlib
(cd capi/bind_gen && cargo run --release)

install -D target/aarch64-apple-ios/release/liblivesplit_core.a "$ROOT/Vendor/livesplit-core/ios-arm64/liblivesplit_core.a"
install -D target/release/liblivesplit_core.a "$ROOT/Vendor/livesplit-core/linux-x86_64/liblivesplit_core.a"
cp capi/bindings/swift/CLiveSplitCore/include/livesplit_core.h "$ROOT/Sources/CLiveSplitCore/include/"
cp capi/bindings/swift/LiveSplitCore/LiveSplitCore.swift "$ROOT/Sources/LiveSplitCore/"
echo "livesplit-core $(git rev-parse HEAD) vendored."

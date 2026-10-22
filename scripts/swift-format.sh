#!/bin/sh
# Lint (default) or format every tracked Swift file with the swift-format that ships with Xcode.
# Usage: scripts/swift-format.sh [lint|format]
set -eu
cd "$(git rev-parse --show-toplevel)"
case "${1:-lint}" in
    lint) set -- lint --strict ;;
    format) set -- format --in-place ;;
    *) echo "usage: $0 [lint|format]" >&2; exit 2 ;;
esac
git ls-files -z '*.swift' | xargs -0 xcrun swift-format "$@" --parallel

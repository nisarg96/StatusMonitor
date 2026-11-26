#!/bin/bash
# Runs SwiftLint. Homebrew's swiftlint loads sourcekitdInProc from the Command Line Tools
# only when DYLD_FRAMEWORK_PATH points there; without it, swiftlint aborts on startup.
set -euo pipefail
cd "$(dirname "$0")"
export DYLD_FRAMEWORK_PATH="${DYLD_FRAMEWORK_PATH:-/Library/Developer/CommandLineTools/usr/lib}"
exec swiftlint lint --strict "$@"

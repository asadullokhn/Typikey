#!/bin/bash
# Measure what the corpus costs, natively, in about a second.
#
# The board logic in Shared/ is Foundation-only on purpose, so it compiles
# and runs on this Mac — no simulator, no device, no keyboard install.
set -euo pipefail
cd "$(dirname "$0")/../.."
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
xcrun swiftc -O -o "$out/tapcost" \
  Shared/Vocabulary.swift \
  Shared/Grammar.swift \
  Shared/SentenceShape.swift \
  Shared/BoardPlan.swift \
  Tools/tapcost/main.swift
"$out/tapcost" "$@"

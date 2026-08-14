#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
xcrun swiftc -O -o "$out/correction-eval" \
  Shared/PredictionTypes.swift \
  Shared/TouchIntentFilter.swift \
  Shared/DoubleMetaphone.swift \
  Shared/CorrectionEngine.swift \
  Tools/correction-eval/main.swift
"$out/correction-eval"

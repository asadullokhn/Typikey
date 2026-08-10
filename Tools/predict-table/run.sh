#!/bin/bash
# Generate a next-word table with the on-device model. Table to stdout,
# progress to stderr, so it pipes straight into a file.
set -euo pipefail
cd "$(dirname "$0")/../.."
out=$(mktemp -d); trap 'rm -rf "$out"' EXIT
xcrun swiftc -O -parse-as-library -o "$out/predict" \
  Shared/Vocabulary.swift Tools/predict-table/main.swift
"$out/predict" "$@"

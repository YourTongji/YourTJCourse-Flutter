#!/usr/bin/env bash
# Read the version from pubspec.yaml.
# Outputs the version string (e.g. "1.0.0").
set -euo pipefail
cd "$(dirname "$0")/.."
sed -nE 's/^version: "?([^"]+)"?/\1/p' pubspec.yaml

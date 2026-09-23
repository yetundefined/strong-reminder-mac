#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"

temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT

swiftc -parse-as-library -o "$temporary/core-tests" AlarmCore.swift AlarmCoreTests.swift
"$temporary/core-tests"

swiftc -parse-as-library -o "$temporary/panel-tests" AlertPanel.swift AlertPanelTests.swift
"$temporary/panel-tests"

swiftc -parse-as-library -o "$temporary/login-tests" LoginStartup.swift LoginStartupTests.swift
"$temporary/login-tests"

#!/usr/bin/env bash
# Tests scripts/bottle-block.sh against the bottle JSON files in scripts/tests/fixtures.
# Usage: scripts/tests/test-bottle-block.sh (needs jq). Run by the "Scripts" job of test.yml.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
script="$here/../bottle-block.sh"
golden_gate="$here/fixtures/outskirts--3.16.0.arm64_golden_gate.bottle.json"
tahoe="$here/fixtures/outskirts--3.16.0.arm64_tahoe.bottle.json"
url=https://github.com/tiny-earth-moon/outskirts/releases/download/3.16.0
a=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
b=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
failures=0

check() {
  local name=$1 expected=$2 actual=$3
  if [[ $actual == "$expected" ]]; then
    echo "ok - $name"
  else
    echo "not ok - $name"
    diff <(echo "$expected") <(echo "$actual") || true
    failures=$((failures + 1))
  fi
}

exit_status() {
  local status=0
  "$script" "$@" >/dev/null 2>&1 || status=$?
  echo "$status"
}

expected_one="  bottle do
    root_url \"$url\"
    sha256 cellar: :any_skip_relocation, arm64_golden_gate: \"$a\"
  end

Release asset: outskirts-3.16.0.arm64_golden_gate.bottle.tar.gz
Download URL:  $url/outskirts-3.16.0.arm64_golden_gate.bottle.tar.gz"
check "one JSON file" "$expected_one" "$("$script" "$golden_gate")"

expected_two="  bottle do
    root_url \"$url\"
    sha256 cellar: :any_skip_relocation, arm64_tahoe: \"$b\"
    sha256 cellar: :any_skip_relocation, arm64_golden_gate: \"$a\"
  end

Release asset: outskirts-3.16.0.arm64_tahoe.bottle.tar.gz
Download URL:  $url/outskirts-3.16.0.arm64_tahoe.bottle.tar.gz
Release asset: outskirts-3.16.0.arm64_golden_gate.bottle.tar.gz
Download URL:  $url/outskirts-3.16.0.arm64_golden_gate.bottle.tar.gz"
check "two JSON files merged into one block" "$expected_two" "$("$script" "$tahoe" "$golden_gate")"

check "the same tag twice is refused" 65 "$(exit_status "$tahoe" "$tahoe")"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
sed 's/3\.16\.0/3.17.0/g' "$tahoe" >"$tmp/other.json"
check "different versions are refused" 65 "$(exit_status "$golden_gate" "$tmp/other.json")"
check "a missing file is refused" 66 "$(exit_status "$golden_gate" "$tmp/missing.json")"
check "no argument is a usage error" 64 "$(exit_status)"

if [[ $failures -ne 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi

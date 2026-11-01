#!/usr/bin/env bash
# Reads the JSON written by `brew bottle --json` (artifact of .github/workflows/bottle.yml)
# and prints, on stdout only, the `bottle do ... end` block to paste into
# Formula/periphery.rb of the tiny-earth-moon/homebrew-tap tap, then the file name
# the bottle must have on the GitHub release. Writes nothing else.
#
# Usage: scripts/bottle-block.sh <periphery--X.Y.Z.<tag>.bottle.json>
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <bottle.json>" >&2
  exit 64
fi
json=$1
if [[ ! -f $json ]]; then
  echo "error: $json not found" >&2
  exit 66
fi
if ! command -v jq >/dev/null; then
  echo "error: jq is required" >&2
  exit 69
fi

# One formula and one bottle tag per JSON, as `brew bottle --json` writes them.
fields=$(jq -er '
  (to_entries | if length == 1 then .[0].value else error("expected one formula") end) as $f
  | ($f.bottle.tags | to_entries | if length == 1 then .[0] else error("expected one bottle tag") end) as $t
  | [$f.formula.pkg_version, $f.bottle.root_url, ($f.bottle.rebuild // 0 | tostring), $t.key,
     ($t.value.cellar // $f.bottle.cellar), $t.value.sha256, $t.value.filename]
  | if any(.[]; . == null) then error("missing field in the bottle JSON") else map(tostring) end
  | @tsv
' "$json")
IFS=$'\t' read -r version root_url rebuild tag cellar sha256 filename <<<"$fields"

if [[ ! $sha256 =~ ^[0-9a-f]{64}$ ]]; then
  echo "error: invalid sha256 '$sha256' in $json" >&2
  exit 65
fi
if [[ $root_url != */releases/download/"$version" ]]; then
  echo "warning: root_url $root_url does not end with /releases/download/$version" >&2
fi

# Same rules as Homebrew's `brew bottle`: relocatable cellars are symbols, the default
# cellars are omitted, any other cellar is a string.
case $cellar in
  any | any_skip_relocation) cellar_arg="cellar: :$cellar, " ;;
  "" | /opt/homebrew/Cellar | /usr/local/Cellar | /home/linuxbrew/.linuxbrew/Cellar) cellar_arg="" ;;
  *) cellar_arg="cellar: \"$cellar\", " ;;
esac

echo "  bottle do"
echo "    root_url \"$root_url\""
if [[ $rebuild != 0 ]]; then
  echo "    rebuild $rebuild"
fi
echo "    sha256 ${cellar_arg}${tag}: \"$sha256\""
echo "  end"
echo
echo "Release asset: $filename"
echo "Download URL:  $root_url/$filename"

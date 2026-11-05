#!/usr/bin/env bash
# Reads the JSON written by `brew bottle --json` (artifact of .github/workflows/bottle.yml)
# and prints, on stdout only, the `bottle do ... end` block to paste into
# Formula/outskirts.rb of the tiny-earth-moon/homebrew-tap tap, then the file name
# each bottle must have on the GitHub release. Writes nothing else.
#
# Usage: scripts/bottle-block.sh <outskirts--X.Y.Z.<tag>.bottle.json>...
# Several JSON files (one per bottle tag, same version, root_url and rebuild) are merged into
# one block, one sha256 line per tag, then the release asset of each bottle.
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <bottle.json>..." >&2
  exit 64
fi
if ! command -v jq >/dev/null; then
  echo "error: jq is required" >&2
  exit 69
fi

cellar_arg() {
  # Same rules as Homebrew's `brew bottle`: relocatable cellars are symbols, the default
  # cellars are omitted, any other cellar is a string.
  case $1 in
    any | any_skip_relocation) echo "cellar: :$1, " ;;
    "" | /opt/homebrew/Cellar | /usr/local/Cellar | /home/linuxbrew/.linuxbrew/Cellar) echo "" ;;
    *) echo "cellar: \"$1\", " ;;
  esac
}

version="" root_url="" rebuild="" lines="" assets="" seen_tags=" "
for json in "$@"; do
  if [[ ! -f $json ]]; then
    echo "error: $json not found" >&2
    exit 66
  fi
  # One formula and one bottle tag per JSON, as `brew bottle --json` writes them.
  fields=$(jq -er '
    (to_entries | if length == 1 then .[0].value else error("expected one formula") end) as $f
    | ($f.bottle.tags | to_entries | if length == 1 then .[0] else error("expected one bottle tag") end) as $t
    | [$f.formula.pkg_version, $f.bottle.root_url, ($f.bottle.rebuild // 0 | tostring), $t.key,
       ($t.value.cellar // $f.bottle.cellar), $t.value.sha256, $t.value.filename]
    | if any(.[]; . == null) then error("missing field in the bottle JSON") else map(tostring) end
    | join("\u001f")
  ' "$json")
  # The unit separator is not IFS whitespace, so empty fields are kept (bash 3.2 included).
  IFS=$'\x1f' read -r j_version j_root_url j_rebuild tag cellar sha256 filename <<<"$fields"

  if [[ ! $sha256 =~ ^[0-9a-f]{64}$ ]]; then
    echo "error: invalid sha256 '$sha256' in $json" >&2
    exit 65
  fi
  if [[ -z $version ]]; then
    version=$j_version root_url=$j_root_url rebuild=$j_rebuild
  elif [[ $j_version != "$version" || $j_root_url != "$root_url" || $j_rebuild != "$rebuild" ]]; then
    echo "error: $json has version, root_url or rebuild different from $1" >&2
    exit 65
  fi
  if [[ $seen_tags == *" $tag "* ]]; then
    echo "error: bottle tag $tag appears twice" >&2
    exit 65
  fi
  seen_tags+="$tag "
  lines+="    sha256 $(cellar_arg "$cellar")${tag}: \"$sha256\""$'\n'
  assets+="$filename"$'\n'
done

if [[ $root_url != */releases/download/"$version" ]]; then
  echo "warning: root_url $root_url does not end with /releases/download/$version" >&2
fi

echo "  bottle do"
echo "    root_url \"$root_url\""
if [[ $rebuild != 0 ]]; then
  echo "    rebuild $rebuild"
fi
# Tags keep the order of the arguments: pass the JSON files newest macOS first, as Homebrew does.
printf '%s' "$lines"
echo "  end"
echo
while read -r filename; do
  echo "Release asset: $filename"
  echo "Download URL:  $root_url/$filename"
done <<<"${assets%$'\n'}"

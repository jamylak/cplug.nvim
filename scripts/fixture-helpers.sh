#!/bin/sh

set -eu

fixture_root() {
  printf '%s\n' "$ROOT_DIR/tests/fixtures/projects"
}

list_fixtures() {
  find "$(fixture_root)" -mindepth 1 -maxdepth 1 -type d -print | sort | while IFS= read -r path; do
    basename "$path"
  done
}

fixture_path() {
  fixture=$1
  path="$(fixture_root)/$fixture"

  if [ ! -d "$path" ]; then
    printf '%s\n' "unknown fixture: $fixture" >&2
    return 1
  fi

  printf '%s\n' "$path"
}

copy_fixture() {
  fixture=$1
  prefix=${2:-cplug-fixture}
  src=$(fixture_path "$fixture")
  tmp_base=${TMPDIR:-/tmp}
  tmp_base=${tmp_base%/}
  dst=$(mktemp -d "$tmp_base/$prefix-$fixture.XXXXXX")
  cp -R "$src"/. "$dst"/
  printf '%s\n' "$dst"
}

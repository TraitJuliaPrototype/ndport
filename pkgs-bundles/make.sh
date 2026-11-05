#!/usr/bin/env bash
# Writes the bundles and MANIFEST.tsv from ../pkgs. pkgs/ is ignored by this repository;
# these files are how its port branches reach a new machine. Restore with restore.sh.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd); pkgs=$here/../pkgs
rm -f "$here"/*.bundle; m=$here/MANIFEST.tsv; : > "$m"
for d in "$pkgs"/*; do
  [ -d "$d/.git" ] || continue
  n=$(basename "$d"); url=$(git -C "$d" remote get-url origin 2>/dev/null || echo -)
  head=$(git -C "$d" symbolic-ref -q --short HEAD || echo "detached:$(git -C "$d" rev-parse HEAD)")
  printf 'clone\t%s\t%s\t%s\n' "$n" "$url" "$head" >> "$m"
  git -C "$d" for-each-ref --format='%(refname:short) %(objectname)' refs/heads |
    while read -r b s; do printf 'branch\t%s\t%s\t%s\n' "$n" "$b" "$s" >> "$m"; done
  git -C "$d" for-each-ref --format='%(refname:short)' refs/tags | grep -E '^(upstream(-ros)?|p[0-9]+-.*)$' |
    while read -r t; do printf 'tag\t%s\t%s\t%s\n' "$n" "$t" "$(git -C "$d" rev-parse "refs/tags/$t^{commit}")" >> "$m"; done
  extra=(--glob=refs/tags/upstream* --glob=refs/tags/p[0-9]*); case "$head" in detached:*) extra+=(HEAD);; esac
  if [ "$url" = - ]; then
    git -C "$d" bundle create -q "$here/$n.bundle" --branches "${extra[@]}"
  elif [ "$(git -C "$d" rev-list --count --branches "${extra[@]}" --not --remotes)" != 0 ]; then
    git -C "$d" bundle create -q "$here/$n.bundle" --branches "${extra[@]}" --not --remotes 2>/dev/null
  fi
done
for d in "$pkgs"/*; do
  [ -f "$d/.git" ] || continue
  common=$(git -C "$d" rev-parse --path-format=absolute --git-common-dir)
  printf 'worktree\t%s\t%s\t%s\n' "$(basename "$d")" "$(basename "$(dirname "$common")")" "$(git -C "$d" symbolic-ref --short HEAD)" >> "$m"
done

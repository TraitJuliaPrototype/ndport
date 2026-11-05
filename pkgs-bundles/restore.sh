#!/usr/bin/env bash
# Recreates ../pkgs from MANIFEST.tsv and the bundles: each clone from upstream (partial,
# blobs on demand), its branches and stage tags at the recorded commits, its worktrees
# under their names.
# Usage: restore.sh [target-dir, default ../pkgs]
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd); pkgs=${1:-$here/../pkgs}; mkdir -p "$pkgs"
while IFS=$'\t' read -r kind a b c; do
  case "$kind" in
    clone)
      if [ "$b" = - ]; then git init -q "$pkgs/$a"; else git clone -q --filter=blob:none --no-checkout "$b" "$pkgs/$a"; fi
      if [ -f "$here/$a.bundle" ]; then
        git -C "$pkgs/$a" fetch -q --update-head-ok "$here/$a.bundle" '+refs/heads/*:refs/heads/*' '+refs/tags/*:refs/tags/*'
        if git bundle list-heads "$here/$a.bundle" | grep -q ' HEAD$'; then git -C "$pkgs/$a" fetch -q "$here/$a.bundle" HEAD; fi
      fi ;;
    branch) git -C "$pkgs/$a" update-ref "refs/heads/$b" "$c" ;;
    tag) git -C "$pkgs/$a" update-ref "refs/tags/$b" "$c" ;;
  esac
done < "$here/MANIFEST.tsv"
while IFS=$'\t' read -r kind a b c; do
  [ "$kind" = clone ] || continue
  case "$c" in
    detached:*) git -C "$pkgs/$a" checkout -q --detach "${c#detached:}" ;;
    *) git -C "$pkgs/$a" symbolic-ref HEAD "refs/heads/$c"; git -C "$pkgs/$a" reset -q --hard ;;
  esac
done < "$here/MANIFEST.tsv"
while IFS=$'\t' read -r kind a b c; do
  [ "$kind" = worktree ] || continue
  git -C "$pkgs/$b" worktree add -q "$pkgs/$a" "$c"
done < "$here/MANIFEST.tsv"

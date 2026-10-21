#!/usr/bin/env bash
# Clone the packages to port at the versions env_upstream resolved, each its own git repository
# under pkgs/, on a branch `trait-port` from the release; the release is tagged `upstream`.
# Usage: scripts/clone.sh   (needs github.com). Writes VERSIONS.tsv.
# Static.jl 1.4.6 (added for P3) has no release tag: cloned by hand at ab590a78, found by its tree hash.
#     scripts/clone.sh --from-depot <suffix> <Name>...   (no network; P6, E-155) a repository pkgs/<Name>-<suffix>
#         made from the depot's copy (~/.julia/packages/<Name>/<slug>) whose git tree hash equals the manifest's
#         git-tree-sha1; committed, tagged `upstream`, on branch `p6-inside-out`; a VERSIONS.tsv row "from depot".
set -euo pipefail
cd "$(dirname "$0")/.."
M=env_upstream/Manifest.toml
ver()  { awk -v p="[[deps.$1]]" '$0==p{f=1;next} /^\[\[/{f=0} f&&/^version/{gsub(/"/,"",$3);print $3}' $M; }
tree() { awk -v p="[[deps.$1]]" '$0==p{f=1;next} /^\[\[/{f=0} f&&/^git-tree-sha1/{gsub(/"/,"",$3);print $3}' $M; }
if [ "${1:-}" = --from-depot ]; then
  suffix=$2; shift 2
  tmp=$(mktemp -d); git init -q --bare "$tmp/th.git"
  treeof() { rm -f "$tmp/idx"; GIT_INDEX_FILE=$tmp/idx git --git-dir="$tmp/th.git" --work-tree="$1" add -A -f . && GIT_INDEX_FILE=$tmp/idx git --git-dir="$tmp/th.git" write-tree; }
  for name in "$@"; do
    v=$(ver "$name"); t=$(tree "$name"); src=
    for d in "$HOME"/.julia/packages/"$name"/*/; do [ "$(treeof "$d")" = "$t" ] && { src=${d%/}; break; }; done
    [ -n "$src" ] || { echo "$name: no depot copy with tree $t"; exit 1; }
    dir=pkgs/$name-$suffix
    [ -e "$dir" ] && { echo "$dir exists"; exit 1; }
    cp -r "$src" "$dir"; chmod -R u+w "$dir"
    git -C "$dir" init -q -b p6-inside-out
    git -C "$dir" add -A -f .
    git -C "$dir" commit -q -m "$name $v from the depot (${src#$HOME/}), tree $t"
    git -C "$dir" tag upstream
    got=$(git -C "$dir" rev-parse "HEAD^{tree}")
    ok=$([ "$got" = "$t" ] && echo "match (from depot)" || echo "MISMATCH (from depot)")
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$v" "depot:${src#$HOME/.julia/packages/}" . "$(git -C "$dir" rev-parse HEAD)" "$ok" | tee -a VERSIONS.tsv
  done
  rm -rf "$tmp"; exit 0
fi
# name  repository  subdirectory-or-.  tag-pattern (VER substituted)
cat > /dev/null <<'LIST'
LIST
while read -r name repo sub tagpat; do
  [ -z "$name" ] && continue
  dir=pkgs/${repo##*/}
  v=$(ver "$name"); t=$(tree "$name"); tag=${tagpat//VER/$v}
  [ -d "$dir" ] || git clone -q --filter=blob:none "https://github.com/$repo" "$dir"
  git -C "$dir" fetch -q --tags
  c=$(git -C "$dir" rev-parse "$tag^{commit}")
  got=$(git -C "$dir" rev-parse "$c:${sub#./}" 2>/dev/null || git -C "$dir" rev-parse "$c^{tree}")
  [ "$sub" = . ] && got=$(git -C "$dir" rev-parse "$c^{tree}")
  ok=$([ "$got" = "$t" ] && echo match || echo MISMATCH)
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$v" "$repo" "$sub" "$c" "$ok" | tee -a VERSIONS.tsv
done <<'LIST'
NetworkDynamics JuliaDynamics/NetworkDynamics.jl . vVER
SciMLBase SciML/SciMLBase.jl . vVER
DiffEqBase SciML/OrdinaryDiffEq.jl lib/DiffEqBase DiffEqBase-vVER
OrdinaryDiffEqCore SciML/OrdinaryDiffEq.jl lib/OrdinaryDiffEqCore OrdinaryDiffEqCore-vVER
OrdinaryDiffEqTsit5 SciML/OrdinaryDiffEq.jl lib/OrdinaryDiffEqTsit5 OrdinaryDiffEqTsit5-vVER
OrdinaryDiffEqRosenbrock SciML/OrdinaryDiffEq.jl lib/OrdinaryDiffEqRosenbrock OrdinaryDiffEqRosenbrock-vVER
DiffEqCallbacks SciML/DiffEqCallbacks.jl . vVER
SymbolicIndexingInterface SciML/SymbolicIndexingInterface.jl . vVER
RecursiveArrayTools SciML/RecursiveArrayTools.jl . vVER
GraphMakie MakieOrg/GraphMakie.jl . vVER
Makie MakieOrg/Makie.jl Makie vVER
NetworkLayout JuliaGraphs/NetworkLayout.jl . vVER
Graphs JuliaGraphs/Graphs.jl . vVER
Observables JuliaGizmos/Observables.jl . vVER
LIST

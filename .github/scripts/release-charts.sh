#!/usr/bin/env bash
#
# Publie les charts de ./charts comme releases GitHub et met à jour le
# dépôt Helm servi par GitHub Pages (branche gh-pages).
#
# Usage : release-charts.sh <final|rc|reindex>
#
#   final    branche main : publie <chart>-X.Y.Z pour chaque chart dont la
#            version de Chart.yaml n'est pas encore publiée.
#   rc       branches release/* et hotfix/* : publie <chart>-X.Y.Z-rc.N
#            (pre-release GitHub) pour chaque chart dont X.Y.Z n'est pas
#            encore publié et qui a changé depuis la dernière rc.
#   reindex  reconstruit index.yaml à partir de toutes les releases
#            GitHub existantes (récupération en cas d'index incomplet).
#
# Variables attendues (fournies par GitHub Actions) :
#   GITHUB_REPOSITORY, GITHUB_SHA, GH_TOKEN
#
set -euo pipefail

MODE="${1:?usage: $0 <final|rc|reindex>}"
CHARTS_DIR="${CHARTS_DIR:-charts}"
PAGES_DIR="${PAGES_DIR:-.gh-pages}"
REPO="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY manquant}"
SHA="${GITHUB_SHA:-$(git rev-parse HEAD)}"
DOWNLOAD_BASE="https://github.com/${REPO}/releases/download"
SEMVER_RE='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

log()  { echo "==> $*"; }
warn() { echo "::warning::$*"; }
die()  { echo "::error::$*"; exit 1; }

# Lit/écrit la clé `version:` de premier niveau de Chart.yaml (les versions
# des dépendances sont indentées et ne sont donc pas touchées).
chart_field() { sed -n "s/^$2:[[:space:]]*//p" "$1/Chart.yaml" | head -n1 | tr -d "\"' "; }
set_chart_version() { sed -i "s/^version:.*/version: $2/" "$1/Chart.yaml"; }

tag_exists() { git rev-parse -q --verify "refs/tags/$1" >/dev/null; }

# Dernière rc publiée pour <name>-<version>, triée numériquement.
last_rc_number() {
  git tag -l "$1-$2-rc.*" \
    | sed -n "s/^$1-$2-rc\.\([0-9][0-9]*\)$/\1/p" \
    | sort -n | tail -n1
}

prepare_pages() {
  if git ls-remote --exit-code --heads origin gh-pages >/dev/null 2>&1; then
    git fetch --quiet origin gh-pages
    git worktree add --quiet --detach "$PAGES_DIR" origin/gh-pages
  else
    log "Branche gh-pages absente : création"
    git worktree add --quiet --detach "$PAGES_DIR"
    git -C "$PAGES_DIR" checkout --quiet --orphan gh-pages
    git -C "$PAGES_DIR" rm -rfq . >/dev/null 2>&1 || true
  fi
  touch "$PAGES_DIR/.nojekyll"
  if [[ ! -f "$PAGES_DIR/index.yaml" ]]; then
    printf 'apiVersion: v1\nentries: {}\n' > "$PAGES_DIR/index.yaml"
  fi
  if [[ ! -f "$PAGES_DIR/index.html" ]]; then
    local owner="${REPO%%/*}" name="${REPO#*/}"
    cat > "$PAGES_DIR/index.html" <<EOF
<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><title>${name}</title></head>
<body>
<h1>Dépôt Helm ${name}</h1>
<pre>helm repo add ${name} https://${owner,,}.github.io/${name}
helm repo update
helm search repo ${name}/ --versions          # versions de production
helm search repo ${name}/ --versions --devel  # avec les release candidates</pre>
<p><a href="index.yaml">index.yaml</a></p>
</body></html>
EOF
  fi
}

# Ajoute un package à index.yaml avec l'URL de sa release GitHub.
index_package() {
  local pkg="$1" tag="$2" dir
  dir="$(mktemp -d -p "$WORK_DIR")"
  cp "$pkg" "$dir/"
  helm repo index "$dir" --url "$DOWNLOAD_BASE/$tag" --merge "$PAGES_DIR/index.yaml"
  cp "$dir/index.yaml" "$PAGES_DIR/index.yaml"
}

publish_pages() {
  git -C "$PAGES_DIR" add -A
  if git -C "$PAGES_DIR" diff --cached --quiet; then
    log "index.yaml inchangé"
    return
  fi
  git -C "$PAGES_DIR" -c user.name="github-actions[bot]" \
    -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
    commit --quiet -m "Mise à jour de l'index Helm ($MODE, ${SHA:0:7})"
  git -C "$PAGES_DIR" push --quiet origin HEAD:gh-pages
  log "index.yaml publié sur gh-pages"
}

release_charts() {
  local published=0 chart name version tag pkg_version n last_rc
  local -a gh_flags

  for chart in "$CHARTS_DIR"/*/; do
    chart="${chart%/}"
    [[ -f "$chart/Chart.yaml" ]] || continue
    name="$(chart_field "$chart" name)"
    version="$(chart_field "$chart" version)"

    [[ "$version" =~ $SEMVER_RE ]] \
      || die "$chart/Chart.yaml : version '$version' invalide, attendu X.Y.Z (les suffixes -rc.N sont ajoutés par la CI)"

    if tag_exists "$name-$version"; then
      if ! git diff --quiet "$name-$version" "$SHA" -- "$chart"; then
        warn "$name : modifié depuis $name-$version mais la version n'a pas été incrémentée, rien n'est publié"
      else
        log "$name $version déjà publié"
      fi
      continue
    fi

    if [[ "$MODE" == final ]]; then
      tag="$name-$version"
      pkg_version="$version"
      gh_flags=(--latest=false)
    else
      last_rc="$(last_rc_number "$name" "$version")"
      if [[ -n "$last_rc" ]] && git diff --quiet "$name-$version-rc.$last_rc" "$SHA" -- "$chart"; then
        log "$name : aucun changement depuis $name-$version-rc.$last_rc"
        continue
      fi
      n=$(( ${last_rc:-0} + 1 ))
      pkg_version="$version-rc.$n"
      tag="$name-$pkg_version"
      gh_flags=(--prerelease --latest=false)
    fi

    log "Publication de $tag"
    set_chart_version "$chart" "$pkg_version"
    helm dependency update "$chart" >/dev/null
    helm package "$chart" --destination "$WORK_DIR" >/dev/null
    git checkout --quiet -- "$chart/Chart.yaml"

    gh release create "$tag" "$WORK_DIR/$name-$pkg_version.tgz" \
      --repo "$REPO" --target "$SHA" --title "$tag" \
      --notes "Chart Helm \`$name\` version \`$pkg_version\` (commit ${SHA:0:7})." \
      "${gh_flags[@]}"
    git fetch --quiet origin "refs/tags/$tag:refs/tags/$tag"

    index_package "$WORK_DIR/$name-$pkg_version.tgz" "$tag"
    published=$(( published + 1 ))
  done

  log "$published chart(s) publié(s)"
}

reindex() {
  local tag dl
  printf 'apiVersion: v1\nentries: {}\n' > "$PAGES_DIR/index.yaml"
  while read -r tag; do
    [[ -n "$tag" ]] || continue
    dl="$(mktemp -d -p "$WORK_DIR")"
    if gh release download "$tag" --repo "$REPO" --pattern '*.tgz' --dir "$dl" 2>/dev/null; then
      for pkg in "$dl"/*.tgz; do
        log "Indexation de $tag"
        index_package "$pkg" "$tag"
      done
    else
      warn "$tag : aucun package .tgz attaché, ignoré"
    fi
  done < <(gh release list --repo "$REPO" --limit 1000 --json tagName --jq '.[].tagName')
}

git fetch --quiet --tags --force origin
prepare_pages

case "$MODE" in
  final|rc) release_charts ;;
  reindex)  reindex ;;
  *) die "mode inconnu : $MODE" ;;
esac

publish_pages

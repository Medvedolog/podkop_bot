#!/usr/bin/env bash
# Publish an immutable, checksum-verified test candidate. Stable stays untouched.
set -Eeuo pipefail
repo="$1"
sha="$2"
title="$3"
tag=test-0.20.2-r3
test "$GITHUB_REPOSITORY" = "$repo"
case "$repo" in
  Medvedolog/luci-app-podkop-bearguard) stable=0.19.24-1 ;;
  Medvedolog/podkop_bot) stable=v0.19.21 ;;
  *) exit 2 ;;
esac
test "$GITHUB_REF" = refs/heads/automation/publish-test-0202-r3
test "$(gh api "repos/$repo/releases/latest" --jq '.tag_name')" = "$stable"
if gh release view "$tag" -R "$repo" >/dev/null 2>&1; then
  echo "::error::Release $tag already exists; not replacing it."
  exit 1
fi
if gh api "repos/$repo/git/ref/tags/$tag" >/dev/null 2>&1; then
  echo "::error::Tag $tag already exists; not replacing it."
  exit 1
fi
(cd upload && sha256sum --strict -c SHA256SUMS)
gh release create "$tag" -R "$repo" --draft --prerelease --latest=false \
  --target "$sha" --title "$title" --notes-file release-notes.md upload/*
gh release view "$tag" -R "$repo" --json assets,isDraft,isPrerelease,targetCommitish > draft.json
jq -e --arg sha "$sha" '.isDraft and .isPrerelease and .targetCommitish == $sha' draft.json
jq -r '.assets[].name' draft.json | LC_ALL=C sort > actual-assets
printf '%s\n' upload/* | sed 's|^upload/||' | LC_ALL=C sort > expected-assets
cmp actual-assets expected-assets
id=$(gh api "repos/$repo/releases/tags/$tag" --jq '.id') || id=
if test -z "$id" || test "$id" = null; then
  id=$(gh api --paginate "repos/$repo/releases?per_page=100" | jq -ers --arg tag "$tag" '[.[][] | select(.tag_name == $tag and .draft == true)] | if length == 1 then .[0].id else error("expected one draft") end')
fi
gh api "repos/$repo/releases/$id" > release.json
for f in upload/*; do
  a=$(basename "$f")
  expected="sha256:$(sha256sum "$f" | cut -d' ' -f1)"
  test "$(jq -er --arg a "$a" '.assets[]|select(.name==$a)|.digest' release.json)" = "$expected"
done
gh release edit "$tag" -R "$repo" --draft=false --prerelease --latest=false
gh release view "$tag" -R "$repo" --json url,isDraft,isPrerelease,tagName,targetCommitish |
  jq -er --arg tag "$tag" --arg sha "$sha" '. | select(.isPrerelease and (.isDraft | not) and .tagName == $tag and .targetCommitish == $sha) | .url'
test "$(gh api "repos/$repo/git/ref/tags/$tag" --jq '.object.sha')" = "$sha"
test "$(gh api "repos/$repo/releases/latest" --jq '.tag_name')" = "$stable"

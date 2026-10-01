#!/usr/bin/env bash
# Linux build host; requires Go, Git, zip, tar, and sha256sum.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
export CGO_ENABLED=0
export GOSUMDB=sum.golang.org

test -s go.sum
git ls-files --error-unmatch go.sum >/dev/null
go mod download
go mod verify
go mod tidy -diff
go vet -mod=readonly ./...
go test -mod=readonly -count=1 ./...

# Include the dependency source and licenses alongside statically linked builds.
# This is a build-time download/packaging step, not generator behavior.
go mod vendor
test -s vendor/github.com/ethereum/go-ethereum/COPYING.LESSER
if [[ -e dist ]]; then
  echo 'dist already exists; move it aside before making a new release.' >&2
  exit 1
fi
mkdir dist
root="$PWD"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

mkdir -p "$stage/licenses"
cp "$(go env GOROOT)/LICENSE" "$stage/licenses/GO-LICENSE"
while IFS= read -r -d '' file; do
  relative="${file#vendor/}"
  mkdir -p "$stage/licenses/$(dirname "$relative")"
  cp "$file" "$stage/licenses/$relative"
done < <(find vendor -type f \( -iname 'LICENSE*' -o -iname 'LICENCE*' -o -iname 'COPYING*' -o -iname 'NOTICE*' -o -iname 'COPYRIGHT*' -o -iname 'AUTHORS*' -o -iname 'PATENTS*' \) -print0)

{
  go version
  printf 'Source commit: '
  git rev-parse HEAD
  printf 'Build flags: CGO_ENABLED=0 -mod=vendor -trimpath -buildvcs=false\n'
} > dist/BUILDINFO.txt

for target in linux/amd64 linux/arm64 windows/amd64 windows/arm64 darwin/amd64 darwin/arm64; do
  os="${target%/*}"
  arch="${target#*/}"
  name="coldwalletgenerator-${os}-${arch}"
  package="$stage/$name"
  mkdir "$package"
  executable=coldwalletgenerator
  if [[ "$os" == windows ]]; then executable+=.exe; fi
  GOOS="$os" GOARCH="$arch" go build -mod=vendor -trimpath -buildvcs=false -o "$package/$executable" .
  cp README.md LICENSE THIRD_PARTY_NOTICES.md "$package/"
  cp -R "$stage/licenses" "$package/third-party-licenses"
  (cd "$package" && zip -q -r "$root/dist/$name.zip" .)
  go version -m "$package/$executable" >> dist/BUILDINFO.txt
done

tar -czf dist/coldwalletgenerator-source-with-dependencies.tar.gz \
  --transform='s,^,coldwalletgenerator/,' \
  main.go main_test.go go.mod go.sum README.md LICENSE SECURITY.md \
  REVIEW.md THIRD_PARTY_NOTICES.md .gitattributes .gitignore .github scripts vendor
(cd dist && sha256sum coldwalletgenerator-* BUILDINFO.txt > SHA256SUMS)
echo 'Packages built. Review them before publishing the draft release.'

#!/usr/bin/env bash
# Linux packaging host; requires Go, Git, Python 3, zip, tar, and sha256sum.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
export CGO_ENABLED=0
export GOSUMDB=sum.golang.org

prebuilt=false
if [[ $# -eq 1 && "$1" == --prebuilt ]]; then
  prebuilt=true
elif [[ $# -ne 0 ]]; then
  echo 'Usage: build-release.sh [--prebuilt]' >&2
  exit 1
fi
if [[ -e dist ]]; then
  echo 'dist already exists; move it aside before making a new release.' >&2
  exit 1
fi

test -s go.sum
git ls-files --error-unmatch go.sum >/dev/null
go mod download
go mod verify
go mod tidy -diff
if ! $prebuilt; then
  # Manual cross-build mode is retained, but is not native execution validation.
  go vet -mod=readonly ./...
  go test -mod=readonly -count=1 ./...
else
  # Artifacts were validated by collect_binaries.py in the same workflow run.
  # Check source/target/toolchain and every binary again before packaging.
  python3 - <<'PY'
import hashlib
import json
import subprocess
from pathlib import Path
from scripts.collect_binaries import TARGETS
commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
go_version = subprocess.check_output(['go', 'env', 'GOVERSION'], text=True).strip()
for target in TARGETS:
    name = 'coldwalletgenerator' + ('.exe' if target.startswith('windows-') else '')
    directory = Path('bin') / target
    info = json.loads((directory / 'build-info.json').read_text())
    expected = {
        'source_commit': commit, 'target': target, 'go_version': go_version,
        'sha256': hashlib.sha256((directory / name).read_bytes()).hexdigest(),
    }
    if info != expected:
        raise SystemExit('Prebuilt binary metadata mismatch: ' + target)
PY
  (cd bin && sha256sum --check SHA256SUMS)
fi

# Build-time dependency/license packaging only; never run a wallet generator here.
go mod vendor
test -s vendor/github.com/ethereum/go-ethereum/COPYING.LESSER
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
  if $prebuilt; then
    printf 'Mode: package same-run natively tested binaries; no recompilation\n'
    printf 'Build flags: CGO_ENABLED=0 -mod=readonly -trimpath -buildvcs=false\n'
  else
    printf 'Mode: manual cross-build; not six-platform native execution validation\n'
    printf 'Build flags: CGO_ENABLED=0 -mod=vendor -trimpath -buildvcs=false\n'
  fi
} > dist/BUILDINFO.txt

for target in linux/amd64 linux/arm64 windows/amd64 windows/arm64 darwin/amd64 darwin/arm64; do
  os="${target%/*}"
  arch="${target#*/}"
  name="coldwalletgenerator-${os}-${arch}"
  package="$stage/$name"
  mkdir "$package"
  executable=coldwalletgenerator
  if [[ "$os" == windows ]]; then executable+=.exe; fi
  if $prebuilt; then
    cp "bin/${os}-${arch}/$executable" "$package/$executable"
    cp "bin/${os}-${arch}/build-info.json" "$package/build-info.json"
    cmp "bin/${os}-${arch}/$executable" "$package/$executable"
  else
    GOOS="$os" GOARCH="$arch" go build -mod=vendor -trimpath -buildvcs=false -o "$package/$executable" .
  fi
  chmod +x "$package/$executable"
  cp README.md LICENSE THIRD_PARTY_NOTICES.md "$package/"
  cp -R "$stage/licenses" "$package/third-party-licenses"
  (cd "$package" && zip -q -r "$root/dist/$name.zip" .)
  go version -m "$package/$executable" >> dist/BUILDINFO.txt
done

tar --exclude='__pycache__' -czf dist/coldwalletgenerator-source-with-dependencies.tar.gz \
  --transform='s,^,coldwalletgenerator/,' \
  main.go main_test.go go.mod go.sum README.md LICENSE SECURITY.md \
  REVIEW.md THIRD_PARTY_NOTICES.md .gitattributes .gitignore .github scripts vendor
(cd dist && sha256sum coldwalletgenerator-* BUILDINFO.txt > SHA256SUMS)
echo 'Packages built. Review them before publishing the draft release.'

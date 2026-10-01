#!/usr/bin/env bash
# Build online; generate real wallets only on a trusted offline computer.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
export CGO_ENABLED=0
export GOSUMDB=sum.golang.org
export GOTOOLCHAIN=auto

test -s go.sum || { echo 'Missing dependency lockfile.' >&2; exit 1; }
go mod download
go mod verify
go mod tidy -diff
if [[ -n "$(gofmt -l main.go main_test.go)" ]]; then
  echo 'Go files are not formatted.' >&2
  exit 1
fi
go vet -mod=readonly ./...
go test -mod=readonly -count=1 ./...
mkdir -p build
go build -mod=readonly -trimpath -buildvcs=false -o build/coldwalletgenerator .
echo 'Build and tests passed. No wallet output was printed or saved.'

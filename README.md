# offline Wallet Generator

Generate a random EVM address and private key locally on your own computer.

The binaries are built by GitHub Actions. You do **not** need to build anything yourself.

## 1. Clone

```sh
git clone https://github.com/CypherTroopers/offlinewalletgenerator.git
cd offlinewalletgenerator
```

## 2. Go offline

Turn off Wi-Fi and disconnect Ethernet.

## 3. Run

### Linux — Intel / AMD

```sh
./bin/linux-amd64/coldwalletgenerator
```

### Linux — ARM64

```sh
./bin/linux-arm64/coldwalletgenerator
```

### Windows — Intel / AMD

```powershell
.\bin\windows-amd64\coldwalletgenerator.exe
```

### Windows — ARM64

```powershell
.\bin\windows-arm64\coldwalletgenerator.exe
```

### Mac — Apple Silicon

```sh
./bin/darwin-arm64/coldwalletgenerator
```

### Mac — Intel

```sh
./bin/darwin-amd64/coldwalletgenerator
```

The app displays:

```text
Address:
0x...

Private Key:
0x...
```

Keep the private key secret. Nothing is saved automatically by the app. Terminal
recording, redirection, swap, and backups can still retain it; see [SECURITY.md](SECURITY.md).

## Platform validation and distribution

Actions is configured to build and execute the generator natively on all six targets:

| Target | GitHub-hosted runner | Binary directory |
| --- | --- | --- |
| Linux x64 | `ubuntu-24.04` | `bin/linux-amd64/` |
| Linux ARM64 | `ubuntu-24.04-arm` | `bin/linux-arm64/` |
| Windows x64 | `windows-2022` | `bin/windows-amd64/` |
| Windows ARM64 | `windows-11-arm` | `bin/windows-arm64/` |
| macOS Apple Silicon | `macos-14` | `bin/darwin-arm64/` |
| macOS Intel | `macos-15-intel` | `bin/darwin-amd64/` |

Check the [Actions run](https://github.com/CypherTroopers/offlinewalletgenerator/actions)
for the exact source commit. Configuration alone is not a passing test, and these
six OS/CPU targets are not a guarantee for every OS version, device, or mobile OS.

Every native job checks the host/toolchain architecture, module checksums, formatting,
static analysis, unit tests, and the actual executable. Generated CI keys are
throwaway; wallet output is discarded and never uploaded. Do not fund CI-generated keys.

Only after all jobs pass, CI copies the **same tested executables**, without rebuilding,
into `bin/` on `main`. Each target includes `build-info.json` with its source commit,
target, Go version, and SHA-256 digest. `bin/SHA256SUMS` covers all six executables.
An outdated run cannot overwrite a newer source commit: publication checks `main`
and uses a non-forced push. Manual CI runs on `main` can also refresh the binaries.

Tag pushes matching `v*` run the same native tests and package those exact executables
as a **draft** release, including dependency sources and license notices. The shared
verification workflow has read-only repository permissions. Only publication jobs
have write permission. External Actions are pinned to full commit SHAs.

Checksums from the same distribution channel are not independent authentication.
CI runners are online; native execution tests do not prove an air gap or certify a
user's computer. Real wallets must be generated on a trusted offline computer.

### Maintainer packaging

`bash scripts/build-release.sh --prebuilt` packages the `bin/` files collected from
the current workflow run and verifies their source/toolchain metadata and checksums.
Without `--prebuilt`, the script retains its manual cross-build mode; those builds
must not be described as having passed all six native execution tests.

Python is used only by build/distribution tooling, not by the wallet executable.

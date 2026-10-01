# Cold Wallet Generator

Generate a random EVM address and private key locally on your own computer.

The binaries are built by GitHub Actions. You do **not** need to build anything yourself.

## 1. Clone

```sh
git clone https://github.com/CypherTroopers/coldwalletgenerator.git
cd coldwalletgenerator
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

Keep the private key secret. Nothing is saved automatically.

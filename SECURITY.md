# Security

This is an experimental private-key generator, not a certified wallet or an independently audited security product. Never send a maintainer a private key, recovery phrase, keystore password, screenshot of a key, or generated wallet output.

## Threat model

The program assumes a trusted OS, compiler, executable, dependency source, random-number generator, display, and backup process. It does not detect infection or guarantee an air gap. A disconnected infected computer can retain secrets and exfiltrate them when reconnected.

Generated private keys are displayed in plaintext. Terminal scrollback, recording, clipboard tools, cameras, remote sessions, swap, crash dumps, and backups can retain them. This program does not encrypt, save, erase, lock memory, or verify backups. Users must decide how to protect the generation device and offline storage.

An ordinary program cannot establish the absence of malware. No prevalence estimate about compromised personal computers is assumed here.

Importing a key into an online wallet exposes it to that wallet and environment. A sweeper can act before you rotate the funds. Rotation is not protection for the import window. A signature does not inherently exhaust an ECDSA key.

## Release requirements

Before a public binary release, resolve and review real dependency checksums; run tests and static analysis against the real dependencies; inspect current dependency and toolchain security advisories; test actual binaries on supported OSes; and review the release source, license notices, and build provenance. Do not generate real wallets in CI or publish randomly generated private keys in test logs.

Checksums obtained from the same compromised distribution channel as a binary are not independent authentication. Protect the repository and maintainer accounts, review updates, and preserve full-commit Action pins.

## Reporting

Use GitHub's private vulnerability reporting if the repository owner has enabled it. Otherwise, request a private reporting channel without disclosing exploit details or secrets in a public issue. No private reporting service is claimed to be enabled by this source package.

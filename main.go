package main

import (
	"crypto/ecdsa"
	"fmt"
	"io"
	"os"

	"github.com/ethereum/go-ethereum/crypto"
)

func main() {
	if len(os.Args) != 1 {
		fmt.Fprintln(os.Stderr, "Usage: coldwalletgenerator (no arguments)")
		os.Exit(1)
	}
	if err := generateWallet(os.Stdout, crypto.GenerateKey); err != nil {
		// Do not include error details that could contain secret output.
		fmt.Fprintln(os.Stderr, "Generation failed. Discard any incomplete output and try again.")
		os.Exit(1)
	}
}

// The injected function makes failure paths testable. Production always uses
// crypto.GenerateKey; there is no seed, environment, or command-line override.
func generateWallet(out io.Writer, newKey func() (*ecdsa.PrivateKey, error)) error {
	key, err := newKey()
	if err != nil {
		return err
	}

	_, err = fmt.Fprintf(out, `COLD WALLET GENERATOR

Use only on a trusted, offline computer.
This program does not check your network connection.
The private key below is NOT encrypted.

Address:
%s

Private Key:
0x%x

Never share, photograph, cloud-sync, or commit your private key.
Securely back up and verify it BEFORE sending assets to the address.
Importing this key into an online wallet makes it a hot-wallet key.
Rotating afterward does not protect funds during a compromised import.
`, crypto.PubkeyToAddress(key.PublicKey).Hex(), crypto.FromECDSA(key))
	return err
}

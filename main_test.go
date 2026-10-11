package main

import (
	"bytes"
	"crypto/ecdsa"
	"errors"
	"fmt"
	"io"
	"strings"
	"testing"

	"github.com/ethereum/go-ethereum/crypto"
)

// Public test fixture only. NEVER send assets to this address.
const testPrivateKey = "0000000000000000000000000000000000000000000000000000000000000001"
const testAddress = "0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf"

func knownKey(t *testing.T) *ecdsa.PrivateKey {
	t.Helper()
	key, err := crypto.HexToECDSA(testPrivateKey)
	if err != nil {
		t.Fatal("could not decode the public test fixture")
	}
	return key
}

func TestKnownPrivateKeyAddress(t *testing.T) {
	if crypto.PubkeyToAddress(knownKey(t).PublicKey).Hex() != testAddress {
		t.Fatal("known EVM address mismatch")
	}
}

func TestOutputAndLeadingZeroPreservation(t *testing.T) {
	var out bytes.Buffer
	calls := 0
	err := generateWallet(&out, func() (*ecdsa.PrivateKey, error) {
		calls++
		return knownKey(t), nil
	})
	if err != nil || calls != 1 {
		t.Fatal("expected one successful key generation")
	}
	for _, expected := range []string{
		"Address:\n" + testAddress + "\n",
		"Private Key:\n0x" + testPrivateKey + "\n",
		"NOT encrypted",
		"does not check your network connection",
		"hot-wallet key",
	} {
		if !strings.Contains(out.String(), expected) {
			t.Fatal("missing or incorrectly formatted output")
		}
	}
}

func TestGenerationFailureProducesNoWallet(t *testing.T) {
	var out bytes.Buffer
	want := errors.New("test key generation failure")
	err := generateWallet(&out, func() (*ecdsa.PrivateKey, error) {
		return nil, want
	})
	if !errors.Is(err, want) || out.Len() != 0 {
		t.Fatal("generation failure must return an error without wallet output")
	}
}

type failingWriter struct{ err error }

func (w failingWriter) Write([]byte) (int, error) { return 0, w.err }

func TestOutputFailure(t *testing.T) {
	want := errors.New("test output failure")
	err := generateWallet(failingWriter{want}, func() (*ecdsa.PrivateKey, error) {
		return knownKey(t), nil
	})
	if !errors.Is(err, want) {
		t.Fatal("output failure was not propagated")
	}
}

func TestRandomKeyRoundTrip(t *testing.T) {
	seen := make(map[string]bool)
	for i := 0; i < 64; i++ {
		key, err := crypto.GenerateKey()
		if err != nil {
			t.Fatal("random key generation failed")
		}
		raw := crypto.FromECDSA(key)
		if len(raw) != 32 || key.D.Sign() <= 0 || key.D.Cmp(crypto.S256().Params().N) >= 0 {
			t.Fatal("invalid private key size or scalar range")
		}
		restored, err := crypto.HexToECDSA(fmt.Sprintf("%x", raw))
		if err != nil {
			t.Fatal("private key re-import failed")
		}
		address := crypto.PubkeyToAddress(key.PublicKey).Hex()
		if crypto.PubkeyToAddress(restored.PublicKey).Hex() != address || seen[address] {
			t.Fatal("address mismatch or duplicate in smoke test")
		}
		seen[address] = true
	}
	// This is a smoke test, not a proof of randomness or entropy quality.
}

func TestGenerateToDiscard(t *testing.T) {
	if err := generateWallet(io.Discard, crypto.GenerateKey); err != nil {
		t.Fatal("production generator failed")
	}
}

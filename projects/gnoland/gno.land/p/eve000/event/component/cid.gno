package component

import (
	"crypto/sha256"
	"encoding/base32"
	"encoding/hex"
	"strings"
	"time"
)

func BuildMerkleRoot(elements []string) string {
	if len(elements) == 0 {
		return ""
	}
	if len(elements) == 1 {
		return elements[0]
	}

	var nextLevel []string
	for i := 0; i < len(elements); i += 2 {
		if i+1 < len(elements) {
			combined := elements[i] + elements[i+1]
			nextLevel = append(nextLevel, HashString(combined))
		} else {
			nextLevel = append(nextLevel, elements[i])
		}
	}
	return BuildMerkleRoot(nextLevel)
}

func HashStrings(elements ...string) string {
	combined := ""
	for _, e := range elements {
		combined += e
	}
	return HashString(combined)
}

func HashString(s interface{}) string {
	if s == nil {
		return ""
	}
	if str, ok := s.(string); ok {
		s = str
	} else if t, ok := s.(time.Time); ok {
		s = t.Format(time.RFC3339)
	} else if es, ok := s.(EventStatus); ok {
		s = string(es)
	} else if eam, ok := s.(EventAttendanceMode); ok {
		s = string(eam)
	} else {
		panic("type not supported for hashing: ")
	}

	hash := sha256.Sum256([]byte(s.(string)))
	return hex.EncodeToString(hash[:])
}

// ShaToCid converts a hex-encoded SHA-256 digest into a CIDv1 (base32, multibase "b").
// Layout: <0x01 version><0x55 codec=raw><0x12 mh=sha2-256><0x20 len=32><digest>
func ShaToCid(sha string) string {
	sha = strings.TrimSpace(sha)

	// Decode hex digest (must be 32 bytes for sha2-256)
	digest, err := hex.DecodeString(sha)
	if err != nil || len(digest) != 32 {
		panic("invalid sha256 digest")
	}

	// Assemble CIDv1 bytes
	// 0x01 = version 1
	// 0x55 = multicodec "raw"
	// 0x12 = multihash code for sha2-256, 0x20 = digest length (32)
	buf := make([]byte, 0, 1+1+2+32)
	buf = append(buf, 0x01, 0x55, 0x12, 0x20)
	buf = append(buf, digest...)

	// Base32 (RFC 4648), no padding, lowercase, with multibase 'b' prefix
	enc := base32.StdEncoding.WithPadding(base32.NoPadding)
	return "b" + strings.ToLower(enc.EncodeToString(buf))
}

// IsCIDv1 checks if the given string is a valid CIDv1 in base32 format.
func IsCIDv1(s string) bool {
	if len(s) != 59 {
		return false
	}
	for _, r := range s {
		if !('a' <= r && r <= 'z' || '2' <= r && r <= '7') { // base32 alphabet
			return false
		}
	}
	if !strings.HasPrefix(s, "bafkrei") {
		return false
	}
	return true
}

func MustCIDv1(label, s string) {
	if !IsCIDv1(s) {
		panic("invalid " + label + ": not a CIDv1")
	}
}

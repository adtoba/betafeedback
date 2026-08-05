package api

import (
	"crypto/rsa"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const appleJWKSURL = "https://appleid.apple.com/auth/keys"
const appleIssuer = "https://appleid.apple.com"

type appleJWKS struct {
	Keys []appleJWK `json:"keys"`
}

type appleJWK struct {
	Kty string `json:"kty"`
	Kid string `json:"kid"`
	Use string `json:"use"`
	Alg string `json:"alg"`
	N   string `json:"n"`
	E   string `json:"e"`
}

type appleClaims struct {
	Email         string `json:"email"`
	EmailVerified any    `json:"email_verified"` // bool or string "true"
	IsPrivateEmail any   `json:"is_private_email"`
	Nonce         string `json:"nonce"`
	jwt.RegisteredClaims
}

type appleKeyCache struct {
	mu      sync.Mutex
	keys    map[string]*rsa.PublicKey
	fetched time.Time
}

var appleKeys = &appleKeyCache{}

func (c *appleKeyCache) keyForKid(kid string) (*rsa.PublicKey, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if time.Since(c.fetched) > time.Hour || c.keys == nil {
		if err := c.refreshLocked(); err != nil {
			if c.keys == nil {
				return nil, err
			}
			// Stale keys are better than failing hard when Apple JWKS is briefly down.
		}
	}
	key, ok := c.keys[kid]
	if !ok {
		// Kid rotated — force refresh once.
		if err := c.refreshLocked(); err != nil {
			return nil, err
		}
		key, ok = c.keys[kid]
		if !ok {
			return nil, fmt.Errorf("apple jwks: unknown kid %q", kid)
		}
	}
	return key, nil
}

func (c *appleKeyCache) refreshLocked() error {
	client := &http.Client{Timeout: 10 * time.Second}
	res, err := client.Get(appleJWKSURL)
	if err != nil {
		return fmt.Errorf("fetch apple jwks: %w", err)
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return fmt.Errorf("fetch apple jwks: status %d", res.StatusCode)
	}
	var body appleJWKS
	if err := json.NewDecoder(res.Body).Decode(&body); err != nil {
		return fmt.Errorf("decode apple jwks: %w", err)
	}
	keys := make(map[string]*rsa.PublicKey, len(body.Keys))
	for _, k := range body.Keys {
		pub, err := jwkToRSAPublicKey(k)
		if err != nil {
			continue
		}
		keys[k.Kid] = pub
	}
	if len(keys) == 0 {
		return errors.New("apple jwks: no usable keys")
	}
	c.keys = keys
	c.fetched = time.Now()
	return nil
}

func jwkToRSAPublicKey(k appleJWK) (*rsa.PublicKey, error) {
	if k.Kty != "RSA" {
		return nil, fmt.Errorf("unsupported kty %s", k.Kty)
	}
	nb, err := base64.RawURLEncoding.DecodeString(k.N)
	if err != nil {
		return nil, err
	}
	eb, err := base64.RawURLEncoding.DecodeString(k.E)
	if err != nil {
		return nil, err
	}
	var eInt int
	for _, b := range eb {
		eInt = eInt<<8 + int(b)
	}
	if eInt == 0 {
		return nil, errors.New("invalid exponent")
	}
	return &rsa.PublicKey{
		N: new(big.Int).SetBytes(nb),
		E: eInt,
	}, nil
}

type appleIdentity struct {
	Subject string
	Email   string
}

// validateAppleIdentityToken verifies an Apple Sign In identity token.
// audience must be the app's bundle ID (e.g. com.betafeedback.app).
// When expectedNonce is non-empty, the token's nonce claim must match.
func validateAppleIdentityToken(tokenString, audience, expectedNonce string) (appleIdentity, error) {
	parser := jwt.NewParser(jwt.WithValidMethods([]string{"RS256"}))
	claims := &appleClaims{}
	token, err := parser.ParseWithClaims(tokenString, claims, func(t *jwt.Token) (any, error) {
		kid, _ := t.Header["kid"].(string)
		if kid == "" {
			return nil, errors.New("missing kid")
		}
		return appleKeys.keyForKid(kid)
	})
	if err != nil || !token.Valid {
		return appleIdentity{}, fmt.Errorf("invalid apple token: %w", err)
	}

	if claims.Issuer != appleIssuer {
		return appleIdentity{}, fmt.Errorf("unexpected issuer %q", claims.Issuer)
	}
	audOK := false
	for _, a := range claims.Audience {
		if a == audience {
			audOK = true
			break
		}
	}
	if !audOK {
		return appleIdentity{}, fmt.Errorf("unexpected audience %v", claims.Audience)
	}
	if claims.Subject == "" {
		return appleIdentity{}, errors.New("missing subject")
	}
	if expectedNonce != "" {
		hashed := sha256Hex(expectedNonce)
		if claims.Nonce == "" ||
			(!secureEqual(claims.Nonce, hashed) && !secureEqual(claims.Nonce, expectedNonce)) {
			return appleIdentity{}, errors.New("nonce mismatch")
		}
	}

	email := strings.ToLower(strings.TrimSpace(claims.Email))
	return appleIdentity{Subject: claims.Subject, Email: email}, nil
}

func sha256Hex(s string) string {
	sum := sha256.Sum256([]byte(s))
	return hex.EncodeToString(sum[:])
}

func secureEqual(a, b string) bool {
	if len(a) != len(b) {
		return false
	}
	var v byte
	for i := 0; i < len(a); i++ {
		v |= a[i] ^ b[i]
	}
	return v == 0
}

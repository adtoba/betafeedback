package api

import (
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/adetoba/betafeedback_backend/internal/config"
)

func TestStaticAndJoinRouting(t *testing.T) {
	srv := NewServer(config.Config{AppBaseURL: "https://betafeedback.com"}, nil, slog.New(slog.NewTextHandler(io.Discard, nil)))
	ts := httptest.NewServer(srv.Routes())
	defer ts.Close()

	cases := []struct {
		path     string
		contains string
	}{
		{"/", "clean bugs out"},
		{"/styles.css", "--brand"},
		{"/favicon.svg", "<svg"},
		{"/join/ABC123", "Checking your invite"},
	}
	for _, c := range cases {
		res, err := http.Get(ts.URL + c.path)
		if err != nil {
			t.Fatalf("GET %s: %v", c.path, err)
		}
		body, _ := io.ReadAll(res.Body)
		res.Body.Close()
		if res.StatusCode != http.StatusOK {
			t.Errorf("GET %s: status %d", c.path, res.StatusCode)
		}
		if !strings.Contains(string(body), c.contains) {
			t.Errorf("GET %s: body missing %q", c.path, c.contains)
		}
	}

	// An unknown API route under the SPA catch-all should 404, not serve HTML.
	res, _ := http.Get(ts.URL + "/healthz")
	body, _ := io.ReadAll(res.Body)
	res.Body.Close()
	if res.StatusCode != http.StatusOK || !strings.Contains(string(body), "ok") {
		t.Errorf("healthz still works: status %d body %q", res.StatusCode, body)
	}
}

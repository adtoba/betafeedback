package structurer

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

const (
	defaultOpenAIModel = "gpt-4o-mini"
	openAIChatURL      = "https://api.openai.com/v1/chat/completions"
)

const systemPrompt = `You are a triage assistant for a beta-testing tool. Given a tester's feedback, decide whether it describes a software defect (a bug) as opposed to a feature request, question, or general praise, then produce a clean, developer-ready bug report.

Respond ONLY with a JSON object matching this schema:
{
  "is_bug": boolean,              // true only if the feedback reports a defect
  "title": string,               // concise bug title, at most 80 characters
  "steps": string[],             // 1-6 concrete steps to reproduce
  "expected": string,            // the expected behavior
  "actual": string,              // the actual, buggy behavior
  "severity": "Low" | "Medium" | "High" | "Critical"
}

Stay grounded in the feedback; do not invent specifics. If is_bug is false, still fill the remaining fields on a best-effort basis.`

// openAIClient is a minimal OpenAI Chat Completions client for structuring.
type openAIClient struct {
	apiKey string
	model  string
	http   *http.Client
}

func newOpenAIClient(apiKey, model string) *openAIClient {
	if model == "" {
		model = defaultOpenAIModel
	}
	return &openAIClient{
		apiKey: apiKey,
		model:  model,
		http:   &http.Client{Timeout: 25 * time.Second},
	}
}

type chatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type chatRequest struct {
	Model          string          `json:"model"`
	Messages       []chatMessage   `json:"messages"`
	ResponseFormat json.RawMessage `json:"response_format"`
	Temperature    float64         `json:"temperature"`
}

type chatResponse struct {
	Choices []struct {
		Message chatMessage `json:"message"`
	} `json:"choices"`
	Error *struct {
		Message string `json:"message"`
	} `json:"error"`
}

type analysisJSON struct {
	IsBug    bool     `json:"is_bug"`
	Title    string   `json:"title"`
	Steps    []string `json:"steps"`
	Expected string   `json:"expected"`
	Actual   string   `json:"actual"`
	Severity string   `json:"severity"`
}

// analyze sends the feedback to the model and parses its structured response.
func (c *openAIClient) analyze(ctx context.Context, title, body string) (Analysis, error) {
	userContent := strings.TrimSpace(fmt.Sprintf("Title: %s\n\nFeedback: %s", title, body))

	payload, err := json.Marshal(chatRequest{
		Model: c.model,
		Messages: []chatMessage{
			{Role: "system", Content: systemPrompt},
			{Role: "user", Content: userContent},
		},
		ResponseFormat: json.RawMessage(`{"type":"json_object"}`),
		Temperature:    0.2,
	})
	if err != nil {
		return Analysis{}, err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, openAIChatURL, bytes.NewReader(payload))
	if err != nil {
		return Analysis{}, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+c.apiKey)

	resp, err := c.http.Do(req)
	if err != nil {
		return Analysis{}, err
	}
	defer resp.Body.Close()

	raw, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return Analysis{}, err
	}

	var parsed chatResponse
	if err := json.Unmarshal(raw, &parsed); err != nil {
		return Analysis{}, fmt.Errorf("decode openai response: %w", err)
	}
	if resp.StatusCode != http.StatusOK {
		if parsed.Error != nil {
			return Analysis{}, fmt.Errorf("openai: %s", parsed.Error.Message)
		}
		return Analysis{}, fmt.Errorf("openai: unexpected status %d", resp.StatusCode)
	}
	if len(parsed.Choices) == 0 {
		return Analysis{}, fmt.Errorf("openai: no choices returned")
	}

	var aj analysisJSON
	if err := json.Unmarshal([]byte(parsed.Choices[0].Message.Content), &aj); err != nil {
		return Analysis{}, fmt.Errorf("parse model json: %w", err)
	}
	return normalizeAnalysis(aj), nil
}

// normalizeAnalysis sanitizes model output so downstream code always receives a
// well-formed bug (non-empty title/steps, a valid severity).
func normalizeAnalysis(aj analysisJSON) Analysis {
	title := strings.TrimSpace(aj.Title)
	if title == "" {
		title = "Untitled bug report"
	}
	if len(title) > 80 {
		title = strings.TrimSpace(title[:77]) + "..."
	}

	steps := make([]string, 0, len(aj.Steps))
	for _, st := range aj.Steps {
		if s := strings.TrimSpace(st); s != "" {
			steps = append(steps, s)
		}
	}
	if len(steps) == 0 {
		steps = []string{"Open the app", "Navigate to the affected screen", "Observe the issue"}
	}

	return Analysis{
		IsBug: aj.IsBug,
		Result: Result{
			Title:    title,
			Steps:    steps,
			Expected: strings.TrimSpace(aj.Expected),
			Actual:   strings.TrimSpace(aj.Actual),
			Severity: normalizeSeverity(aj.Severity),
		},
	}
}

func normalizeSeverity(s string) string {
	switch strings.ToLower(strings.TrimSpace(s)) {
	case "critical":
		return "Critical"
	case "high":
		return "High"
	case "medium":
		return "Medium"
	default:
		return "Low"
	}
}

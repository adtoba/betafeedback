package structurer

import (
	"context"
	"log/slog"
)

// Analysis is the combined classification and structuring of a feedback item.
type Analysis struct {
	// IsBug reports whether the feedback describes a defect (as opposed to a
	// feature request, question, or praise).
	IsBug bool
	Result
}

// Config configures the structuring Service.
type Config struct {
	OpenAIAPIKey string
	OpenAIModel  string
}

// Service turns raw tester feedback into structured bug reports. When an OpenAI
// API key is configured it uses the model; otherwise — or whenever a request
// fails — it transparently falls back to local heuristics, so callers always
// get a usable result and never an error.
type Service struct {
	client *openAIClient // nil when no API key is configured
	logger *slog.Logger
}

// NewService builds a Service. With no API key it runs purely on heuristics.
func NewService(cfg Config, logger *slog.Logger) *Service {
	var client *openAIClient
	if cfg.OpenAIAPIKey != "" {
		client = newOpenAIClient(cfg.OpenAIAPIKey, cfg.OpenAIModel)
		logger.Info("structurer: using OpenAI", "model", client.model)
	} else {
		logger.Info("structurer: using heuristics (no OPENAI_API_KEY set)")
	}
	return &Service{client: client, logger: logger}
}

// Enabled reports whether the OpenAI backend is configured.
func (s *Service) Enabled() bool { return s.client != nil }

// Analyze classifies and structures a feedback item. It never fails: on any LLM
// error it logs a warning and falls back to heuristics.
func (s *Service) Analyze(ctx context.Context, title, body string) Analysis {
	if s.client == nil {
		return heuristicAnalysis(title, body)
	}
	analysis, err := s.client.analyze(ctx, title, body)
	if err != nil {
		s.logger.Warn("structurer: openai analyze failed, using heuristics", "err", err)
		return heuristicAnalysis(title, body)
	}
	return analysis
}

func heuristicAnalysis(title, body string) Analysis {
	return Analysis{
		IsBug:  IsBugLike(title, body),
		Result: Structure(title, body),
	}
}

package agent

import (
	"encoding/json"
	"os"
	"regexp"
	"strings"

	"github.com/sipeed/picoclaw/pkg/providers"
)

var (
	privateKeyPattern = regexp.MustCompile(`(?is)-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----`)
	bearerPattern     = regexp.MustCompile(`(?i)\bBearer\s+[A-Za-z0-9._\-+/=]{16,}\b`)
	jwtPattern        = regexp.MustCompile(`\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9._-]{10,}\.[A-Za-z0-9._-]{10,}\b`)
	awsKeyPattern     = regexp.MustCompile(`\bAKIA[0-9A-Z]{16}\b`)
	skKeyPattern      = regexp.MustCompile(`\bsk-[A-Za-z0-9]{16,}\b`)
	urlCredsPattern   = regexp.MustCompile(`([a-z]+://[^/\s:@]+:)([^@\s/]+)(@)`)
	secretKVPattern   = regexp.MustCompile(`(?i)\b(api[_-]?key|access[_-]?token|refresh[_-]?token|auth[_-]?token|password|passwd|secret|client[_-]?secret)\b\s*[:=]\s*(['"]?)([^\s,'"}]{4,})(['"]?)`)
	emailPattern      = regexp.MustCompile(`\b[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\b`)
)

func redactMessagesForLLM(messages []providers.Message) []providers.Message {
	if !isLLMRedactionEnabled() || len(messages) == 0 {
		return messages
	}

	redacted := make([]providers.Message, len(messages))
	for i := range messages {
		msg := messages[i]
		msg.Content = redactText(msg.Content)
		msg.ReasoningContent = redactText(msg.ReasoningContent)

		if len(msg.SystemParts) > 0 {
			systemParts := make([]providers.ContentBlock, len(msg.SystemParts))
			copy(systemParts, msg.SystemParts)
			for j := range systemParts {
				systemParts[j].Text = redactText(systemParts[j].Text)
			}
			msg.SystemParts = systemParts
		}

		if len(msg.ToolCalls) > 0 {
			toolCalls := make([]providers.ToolCall, len(msg.ToolCalls))
			copy(toolCalls, msg.ToolCalls)
			for j := range toolCalls {
				if toolCalls[j].Function != nil {
					fc := *toolCalls[j].Function
					fc.Arguments = redactText(fc.Arguments)
					toolCalls[j].Function = &fc
				}
				if len(toolCalls[j].Arguments) > 0 {
					toolCalls[j].Arguments = redactMap(toolCalls[j].Arguments)
				}
			}
			msg.ToolCalls = toolCalls
		}

		redacted[i] = msg
	}

	return redacted
}

func redactMap(in map[string]any) map[string]any {
	b, err := json.Marshal(in)
	if err != nil {
		return in
	}
	masked := redactText(string(b))
	var out map[string]any
	if err := json.Unmarshal([]byte(masked), &out); err != nil {
		return in
	}
	return out
}

func redactText(input string) string {
	if input == "" {
		return ""
	}

	out := input
	out = privateKeyPattern.ReplaceAllString(out, "[REDACTED_PRIVATE_KEY]")
	out = bearerPattern.ReplaceAllString(out, "Bearer [REDACTED_TOKEN]")
	out = jwtPattern.ReplaceAllString(out, "[REDACTED_JWT]")
	out = awsKeyPattern.ReplaceAllString(out, "[REDACTED_AWS_KEY]")
	out = skKeyPattern.ReplaceAllString(out, "[REDACTED_API_KEY]")
	out = urlCredsPattern.ReplaceAllString(out, "$1[REDACTED]$3")
	out = secretKVPattern.ReplaceAllStringFunc(out, redactSecretKVMatch)

	if isLLMRedactionStrict() {
		out = emailPattern.ReplaceAllString(out, "[REDACTED_EMAIL]")
	}
	return out
}

func redactSecretKVMatch(m string) string {
	idx := strings.IndexAny(m, ":=")
	if idx < 0 {
		return m
	}
	prefix := strings.TrimRight(m[:idx+1], " \t")
	sep := string(m[idx])
	return prefix + sep + " [REDACTED]"
}

func isLLMRedactionEnabled() bool {
	v := strings.TrimSpace(strings.ToLower(os.Getenv("PICOCLAW_LLM_REDACTION_ENABLED")))
	if v == "" {
		return true
	}
	return v != "0" && v != "false" && v != "no" && v != "off"
}

func isLLMRedactionStrict() bool {
	v := strings.TrimSpace(strings.ToLower(os.Getenv("PICOCLAW_LLM_REDACTION_STRICT")))
	return v == "1" || v == "true" || v == "yes" || v == "on"
}

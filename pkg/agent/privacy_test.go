package agent

import (
	"os"
	"strings"
	"testing"

	"github.com/sipeed/picoclaw/pkg/providers"
)

func TestRedactTextSecrets(t *testing.T) {
	input := "Bearer abcdefghijklmnopqrstuvwxyz123456 password=myPass123 api_key: sk-1234567890abcdefghij jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.abcde12345.qwerty98765"
	out := redactText(input)

	if strings.Contains(out, "myPass123") {
		t.Fatalf("password was not redacted: %s", out)
	}
	if strings.Contains(out, "sk-1234567890abcdefghij") {
		t.Fatalf("api key was not redacted: %s", out)
	}
	if strings.Contains(out, "eyJhbGciOiJIUzI1Ni") {
		t.Fatalf("jwt was not redacted: %s", out)
	}
	if !strings.Contains(out, "[REDACTED]") {
		t.Fatalf("expected redacted marker in output: %s", out)
	}
}

func TestRedactMessagesForLLMToolCallArguments(t *testing.T) {
	t.Setenv("PICOCLAW_LLM_REDACTION_ENABLED", "true")
	msgs := []providers.Message{{
		Role:    "assistant",
		Content: "token=abc12345678901234567890",
		ToolCalls: []providers.ToolCall{{
			Function: &providers.FunctionCall{
				Name:      "test",
				Arguments: `{"password":"abc123456"}`,
			},
		}},
	}}

	out := redactMessagesForLLM(msgs)
	if strings.Contains(out[0].Content, "abc123456789") {
		t.Fatalf("message content was not redacted: %s", out[0].Content)
	}
	if strings.Contains(out[0].ToolCalls[0].Function.Arguments, "abc123456") {
		t.Fatalf("tool arguments were not redacted: %s", out[0].ToolCalls[0].Function.Arguments)
	}
}

func TestRedactMessagesForLLMDisabled(t *testing.T) {
	t.Setenv("PICOCLAW_LLM_REDACTION_ENABLED", "false")
	msgs := []providers.Message{{Role: "user", Content: "password=raw-secret"}}
	out := redactMessagesForLLM(msgs)
	if out[0].Content != "password=raw-secret" {
		t.Fatalf("redaction should be disabled, got: %s", out[0].Content)
	}
}

func TestRedactionStrictEmail(t *testing.T) {
	origEnabled, hasEnabled := os.LookupEnv("PICOCLAW_LLM_REDACTION_ENABLED")
	origStrict, hasStrict := os.LookupEnv("PICOCLAW_LLM_REDACTION_STRICT")
	defer func() {
		if hasEnabled {
			_ = os.Setenv("PICOCLAW_LLM_REDACTION_ENABLED", origEnabled)
		} else {
			_ = os.Unsetenv("PICOCLAW_LLM_REDACTION_ENABLED")
		}
		if hasStrict {
			_ = os.Setenv("PICOCLAW_LLM_REDACTION_STRICT", origStrict)
		} else {
			_ = os.Unsetenv("PICOCLAW_LLM_REDACTION_STRICT")
		}
	}()

	_ = os.Setenv("PICOCLAW_LLM_REDACTION_ENABLED", "true")
	_ = os.Setenv("PICOCLAW_LLM_REDACTION_STRICT", "true")
	out := redactText("contact admin@appsmagic.in")
	if strings.Contains(out, "admin@appsmagic.in") {
		t.Fatalf("strict mode should redact email, got: %s", out)
	}
}

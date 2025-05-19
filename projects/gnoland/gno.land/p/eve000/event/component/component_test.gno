package component

import (
	"strings"
	"testing"
)

func TestStringToAnchor(t *testing.T) {
	tests := map[string]string{
		"Hello World!":         "#hello-world",
		"Dr. Who, Sir!":        "#dr-who-sir",
		"Speaker: Alan Kay":    "#speaker-alan-kay",
		"What is this?!?":      "#what-is-this",
		"Complex: Title; Yes.": "#complex-title-yes",
	}

	for input, expected := range tests {
		actual := StringToAnchor(input)
		if actual != expected {
			t.Fatalf("StringToAnchor(%q) = %q; expected %q", input, actual, expected)
		}
	}
}

func TestSplitText(t *testing.T) {
	text := "The quick brown fox jumps over the lazy dog and then runs far away"
	maxLen := 20
	lines := SplitText(text, maxLen)

	for _, line := range lines {
		if len(line) > maxLen {
			t.Errorf("Line too long: %q", line)
		}
	}

	// Join result and check semantic equality
	joined := strings.Join(lines, "")
	original := strings.ReplaceAll(text, " ", "")
	joined = strings.ReplaceAll(joined, " ", "")
	if joined != original {
		t.Errorf("SplitText lines rejoined incorrectly.\nOriginal: %q\nRejoined: %q", original, joined)
	}
}

func TestSvgHeadingOutput(t *testing.T) {
	svg := SvgHeading("600", "100")

	if !strings.HasPrefix(svg, `<svg width="600" height="100"`) {
		t.Fatalf("SvgHeading missing or incorrect width/height declaration")
	}
	if !strings.Contains(svg, `<style>`) || !strings.Contains(svg, `.title { font: bold 24px`) {
		t.Fatalf("SvgHeading missing expected style declarations")
	}
	if !strings.HasSuffix(svg, "</style>") && !strings.Contains(svg, "</style>") {
		t.Fatalf("SvgHeading missing style closing tag")
	}
}

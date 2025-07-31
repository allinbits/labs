package component

import (
	"strings"
	"testing"
)

func sampleSpeaker() *Speaker {
	return &Speaker{
		Name:        "Ken Thompson and Brian Kernighan",
		Biography:   "Creators of UNIX and C",
		Affiliation: "Bell Labs / Princeton",
		PictureURL:  "https://example.com/ken-brian.png",
	}
}

func TestSpeakerToAnchor(t *testing.T) {
	s := sampleSpeaker()
	expected := "#ken-thompson-and-brian-kernighan"
	if anchor := s.ToAnchor(); anchor != expected {
		t.Fatalf("ToAnchor mismatch: expected %q, got %q", expected, anchor)
	}
}

func TestSpeakerToMarkdown(t *testing.T) {
	s := sampleSpeaker()
	md := s.ToMarkdown()

	expected := ""
	expected += "#### Ken Thompson and Brian Kernighan\n\n"
	expected += "Creators of UNIX and C\n\n"
	expected += "Affiliation: Bell Labs / Princeton\n\n"
	expected += "![Picture](https://example.com/ken-brian.png)\n\n"

	if md != expected {
		t.Fatalf("Markdown output mismatch:\n\nExpected:\n%s\n\nGot:\n%s", expected, md)
	}
}

func TestSpeakerToJson(t *testing.T) {
	s := sampleSpeaker()
	actual := s.ToJson()

	expected := ""
	expected += "{\n"
	expected += "  \"Name\":\"Ken Thompson and Brian Kernighan\",\n"
	expected += "  \"Biography\":\"Creators of UNIX and C\",\n"
	expected += "  \"Affiliation\":\"Bell Labs / Princeton\",\n"
	expected += "  \"PictureURL\":\"https://example.com/ken-brian.png\"\n"
	expected += "}"

	if actual != expected {
		t.Fatalf("JSON output mismatch:\n\nExpected:\n%s\n\nGot:\n%s", expected, actual)
	}
}

func TestSpeakerToSVG(t *testing.T) {
	s := sampleSpeaker()
	actual := s.ToSVG()

	expected := ""
	expected += `<svg width="600" height="100" xmlns="http://www.w3.org/2000/svg"><style>.title { font: bold 24px sans-serif; }.subtitle { font: bold 18px sans-serif; }.sessiontitle { font: bold 16px sans-serif; }.text { font: 14px sans-serif; }.speaker { font: 14px sans-serif; font-style: italic; }.session { font: 14px sans-serif; margin-top: 20px; }</style>`
	expected += `<g class="speaker">`
	expected += `<text x="20" y="20" class="speaker">Ken Thompson and Brian Kernighan</text>`
	expected += `<text x="20" y="40" class="text">Creators of UNIX and C</text>`
	expected += `<text x="20" y="60" class="text">Affiliation: Bell Labs / Princeton</text>`
	expected += "</g></svg>"

	if actual != expected {
		t.Fatalf("SVG output mismatch:\n\nExpected:\n%s\n\nGot:\n%s", expected, actual)
	}
}

func TestSpeakerToSvgDataUrl(t *testing.T) {
	s := sampleSpeaker()
	dataUrl := s.ToSvgDataUrl()
	if !strings.HasPrefix(dataUrl, "data:image/svg+xml;utf8,") {
		t.Fatalf("SVG Data URL missing expected prefix, got: %s", dataUrl[:60])
	}
}

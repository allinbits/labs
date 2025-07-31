package session

import (
	"strings"
	"testing"
	"time"

	"gno.land/p/eve000/event/component"
	"gno.land/p/eve000/event/location"
)

func sampleSession() *Session {
	return &Session{
		Title:       "Reviewed Proposals: Ken Thompson interviewed by Brian Kernighan",
		Description: "In the 1960s–1970s, Ken Thompson co-invented the UNIX operating system along with Dennis Ritchie at Bell Labs. He also worked on the language B, the operating system Plan 9, and the language Go. He and Ritchie won the Turing Award. He now works at Google. He’ll be interviewed by Brian Kernighan of “K&R” fame.",
		Speaker:     &component.Speaker{Name: "Ken Thompson and Brian Kernighan", Biography: "Creators of UNIX and C", Affiliation: "Bell Labs / Princeton"},
		StartTime:   time.Date(2025, 4, 3, 14, 0, 0, 0, time.UTC),
		EndTime:     time.Date(2025, 4, 3, 15, 0, 0, 0, time.UTC),
		Location:    &location.Location{Name: "Main Theater"},
		Opts:        &component.RenderOpts{Location: true},
	}
}

func TestSessionToMarkdown_ExpectedOutput(t *testing.T) {
	s := sampleSession()
	md := s.ToMarkdown()
	expectedMarkdown := "" +
		"### Reviewed Proposals: Ken Thompson interviewed by Brian Kernighan\n\n" +
		"2:00PM -> 3:00PM | [Speaker - Ken Thompson and Brian Kernighan](#ken-thompson-and-brian-kernighan)[Location - Main Theater](#main-theater)\n\n" +
		"In the 1960s–1970s, Ken Thompson co-invented the UNIX operating system along with Dennis Ritchie at Bell Labs. He also worked on the language B, the operating system Plan 9, and the language Go. He and Ritchie won the Turing Award. He now works at Google. He’ll be interviewed by Brian Kernighan of “K&R” fame.\n\n" +
		"Duration: 1h0m\n\n"
	if md != expectedMarkdown {
		t.Fatalf("Markdown output mismatch:\n\nExpected:\n%s\n\nGot:\n%s", expectedMarkdown, md)
	}
}

func TestSessionToJson_ExpectedOutput(t *testing.T) {
	s := sampleSession()
	actual := s.ToJson()

	expectedJson := ""
	expectedJson += "{\n"
	expectedJson += "\"Location\":\"Main Theater\",\n"
	expectedJson += "\"Title\":\"Reviewed Proposals: Ken Thompson interviewed by Brian Kernighan\",\n"
	expectedJson += "\"Description\":\"In the 1960s–1970s, Ken Thompson co-invented the UNIX operating system along with Dennis Ritchie at Bell Labs. He also worked on the language B, the operating system Plan 9, and the language Go. He and Ritchie won the Turing Award. He now works at Google. He’ll be interviewed by Brian Kernighan of “K&R” fame.\",\n"
	expectedJson += "\"StartTime\":\"2025-04-03T14:00:00Z\",\n"
	expectedJson += "\"EndTime\":\"2025-04-03T15:00:00Z\"\n"
	expectedJson += "\"Speaker\":{\n"
	expectedJson += "    \"Name\":\"Ken Thompson and Brian Kernighan\",\n"
	expectedJson += "    \"Biography\":\"Creators of UNIX and C\",\n"
	expectedJson += "    \"Affiliation\":\"Bell Labs / Princeton\"\n"
	expectedJson += "  }\n"
	expectedJson += "}"

	if actual != expectedJson {
		t.Fatalf("JSON output mismatch:\n\nExpected:\n%s\n\nGot:\n%s", expectedJson, actual)
	}
}

func TestSessionToSVG_ExpectedOutput(t *testing.T) {
	s := sampleSession()
	svg := s.ToSVG()

	expectedSvg := ""
	expectedSvg += `<svg width="600" height="80" xmlns="http://www.w3.org/2000/svg"><style>.title { font: bold 24px sans-serif; }.subtitle { font: bold 18px sans-serif; }.sessiontitle { font: bold 16px sans-serif; }.text { font: 14px sans-serif; }.speaker { font: 14px sans-serif; font-style: italic; }.session { font: 14px sans-serif; margin-top: 20px; }</style><g class="session">`
	expectedSvg += `<text x="20" y="20" class="speaker">Speaker: Ken Thompson and Brian Kernighan</text>`
	expectedSvg += `<text x="20" y="40" class="text">Start Time: 2:00PM</text>`
	expectedSvg += `<text x="20" y="60" class="text">End Time: 3:00PM</text>`
	expectedSvg += `<text x="20" y="80" class="text">Location: Main Theater</text>`
	expectedSvg += `<text x="200" y="20" class="sessiontitle">Reviewed Proposals: Ken Thompson interviewed by Brian Kernighan</text>`
	expectedSvg += `<text x="200" y="40" class="text">In the 1960s–1970s, Ken Thompson co-invented the</text>`
	expectedSvg += `<text x="200" y="60" class="text"> UNIX operating system along with Dennis Ritchie</text>`
	expectedSvg += `<text x="200" y="80" class="text"> at Bell Labs. He also worked on the language B,</text>`
	expectedSvg += `<text x="200" y="100" class="text"> the operating system Plan 9, and the language Go.</text>`
	expectedSvg += `<text x="200" y="120" class="text"> He and Ritchie won the Turing Award. He now works</text>`
	expectedSvg += `<text x="200" y="140" class="text"> at Google. He’ll be interviewed by Brian</text>`
	expectedSvg += `<text x="200" y="160" class="text"> Kernighan of “K&R” fame.</text></g></svg>`

	if svg != expectedSvg {
		t.Fatalf("SVG output mismatch:\n\nExpected:\n%s\n\nGot:\n%s", expectedSvg, svg)
	}
}

func TestSessionToSvgDataUrl_ExpectedPrefix(t *testing.T) {
	s := sampleSession()
	dataUrl := s.ToSvgDataUrl()

	expectedPrefix := "data:image/svg+xml;utf8,"

	if !strings.HasPrefix(dataUrl, expectedPrefix) {
		t.Fatalf("SVG Data URL does not start with expected prefix:\nExpected: %s\nGot: %s", expectedPrefix, dataUrl[:60])
	}
}

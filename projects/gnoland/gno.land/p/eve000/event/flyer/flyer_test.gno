package flyer

import (
	"strings"
	"testing"
	"time"

	"gno.land/p/eve000/event/component"
	"gno.land/p/eve000/event/location"
	"gno.land/p/eve000/event/session"
)

func sampleFlyer() *Flyer {
	return &Flyer{
		Name:        "UNIX Legends",
		Location:    &location.Location{Name: "Main Theater"},
		StartDate:   time.Date(2025, 4, 3, 0, 0, 0, 0, time.UTC),
		EndDate:     time.Date(2025, 4, 3, 0, 0, 0, 0, time.UTC),
		Description: "A deep dive into the pioneers of the UNIX operating system.",
		Sessions: []*session.Session{
			{
				Title:       "Fireside Chat",
				Description: "Ken Thompson talks about UNIX, Plan 9, and Go.",
				Speaker:     &component.Speaker{Name: "Ken Thompson", Biography: "Co-creator of UNIX", Affiliation: "Bell Labs"},
				StartTime:   time.Date(2025, 4, 3, 14, 0, 0, 0, time.UTC),
				EndTime:     time.Date(2025, 4, 3, 15, 0, 0, 0, time.UTC),
				Location:    &location.Location{Name: "Main Theater"},
				Opts: &component.RenderOpts{
					Location: true,
					Speaker:  true,
					Svg:      true,
				},
			},
		},
		Opts: &component.RenderOpts{Location: true, Speaker: true, Svg: true},
	}
}

func TestFlyerToAnchor(t *testing.T) {
	a := sampleFlyer()
	expected := "#unix-legends"
	if anchor := a.ToAnchor(); anchor != expected {
		t.Fatalf("ToAnchor mismatch: expected %q, got %q", expected, anchor)
	}
}

func TestFlyerToMarkdown(t *testing.T) {
	a := sampleFlyer()
	md := a.ToMarkdown()
	if !strings.Contains(md, "## UNIX Legends") {
		t.Fatal("Markdown output missing agenda title")
	}
	if !strings.Contains(md, "Fireside Chat") {
		t.Fatal("Markdown output missing session title")
	}
	if !strings.Contains(md, "Ken Thompson") {
		t.Fatal("Markdown output missing speaker name")
	}
	if !strings.Contains(md, "## Speakers") {
		t.Fatal("Markdown missing Speakers section")
	}
	if !strings.Contains(md, "## Locations") {
		t.Fatal("Markdown missing Locations section")
	}
}

func TestFlyerToJson(t *testing.T) {
	a := sampleFlyer()
	json := a.ToJson()
	if !strings.Contains(json, `"Name":"UNIX Legends"`) {
		t.Fatal("JSON missing agenda name")
	}
	if !strings.Contains(json, `"Sessions":[`) {
		t.Fatal("JSON missing sessions array")
	}
	if !strings.Contains(json, `"Ken Thompson"`) {
		t.Fatal("JSON missing speaker name")
	}
}

func TestFlyerToSVG(t *testing.T) {
	a := sampleFlyer()
	svg := a.ToSVG()
	if !strings.Contains(svg, `<svg`) || !strings.Contains(svg, `UNIX Legends`) {
		t.Fatal("SVG output missing structure or title")
	}
	if !strings.Contains(svg, `Fireside Chat`) {
		t.Fatal("SVG output missing session content")
	}
}

func TestFlyerToSvgDataUrl(t *testing.T) {
	a := sampleFlyer()
	dataUrl := a.ToSvgDataUrl()
	if !strings.HasPrefix(dataUrl, "data:image/svg+xml;utf8,") {
		t.Fatalf("SVG data URL missing prefix: %s", dataUrl[:60])
	}
}

func TestFlyerRenderIncludesSVG(t *testing.T) {
	a := sampleFlyer()
	render := a.Render()
	if !strings.Contains(render, "data:image/svg+xml;utf8,") {
		t.Fatal("Render output missing SVG data URL")
	}
	if !strings.Contains(render, "## UNIX Legends") {
		t.Fatal("Render output missing Markdown content")
	}
}

package location

import (
	"testing"
)

func sampleLocation() *Location {
	return &Location{
		Name:        "Main Theater",
		Address:     "123 Unix Lane, Bell Labs, NJ",
		Coordinates: "40.6840° N, 74.3990° W",
		Description: "The original UNIX launch venue.",
	}
}

func TestLocationToAnchor(t *testing.T) {
	l := sampleLocation()
	expected := "#main-theater"
	if anchor := l.ToAnchor(); anchor != expected {
		t.Fatalf("ToAnchor mismatch: expected %q, got %q", expected, anchor)
	}
}

func TestLocationToMarkdown(t *testing.T) {
	l := sampleLocation()
	md := l.ToMarkdown()

	expected := ""
	expected += "### Main Theater\n"
	expected += "123 Unix Lane, Bell Labs, NJ\n"
	expected += "40.6840° N, 74.3990° W\n"
	expected += "The original UNIX launch venue.\n"

	if md != expected {
		t.Fatalf("Markdown output mismatch:\n\nExpected:\n%s\n\nGot:\n%s", expected, md)
	}
}

func TestLocationToJson(t *testing.T) {
	l := sampleLocation()
	actual := l.ToJson()

	expected := ""
	expected += "{\n"
	expected += "  \"Name\":\"Main Theater\"\n"
	expected += ",\n"
	expected += "  \"Address\":\"123 Unix Lane, Bell Labs, NJ\"\n"
	expected += ",\n"
	expected += "  \"Coordinates\":\"40.6840° N, 74.3990° W\"\n"
	expected += "}"

	if actual != expected {
		t.Fatalf("JSON output mismatch:\n\nExpected:\n%s\n\nGot:\n%s", expected, actual)
	}
}

func TestLocationToSVG_Panics(t *testing.T) {
	defer func() {
		if r := recover(); r == nil {
			t.Fatal("expected panic from ToSVG, but did not panic")
		}
	}()
	sampleLocation().ToSVG()
}

func TestLocationToSvgDataUrl_Panics(t *testing.T) {
	defer func() {
		if r := recover(); r == nil {
			t.Fatal("expected panic from ToSvgDataUrl (since ToSVG not implemented)")
		}
	}()
	sampleLocation().ToSvgDataUrl()
}

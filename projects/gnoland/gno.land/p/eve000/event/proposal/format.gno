package proposal

import (
	"net/url"
	"strings"

	"gno.land/p/demo/ufmt"
	"gno.land/p/eve000/event/component"
)

type Format struct {
	Name        string
	Description string
	Duration    int
	MinSpeakers int
	MaxSpeakers int
}

func RenderFormats(formats map[string]Format) string {
	var f strings.Builder

	for _, format := range formats {
		md := format.ToMarkdown()
		svg := format.ToSVG()
		dataURL := "data:image/svg+xml;utf8," + url.PathEscape(svg)
		anchor := format.ToAnchor()

		entry := md + "\n[![" + anchor + "](" + dataURL + ")]" + "(" + anchor + ")\n\n---\n\n"

		f.WriteString(entry)
	}

	var markdown strings.Builder

	markdown.WriteString("## Session Proposal Formats:\n\n")
	markdown.WriteString(f.String())

	return markdown.String()
}

func (f *Format) ToAnchor() string {
	return component.StringToAnchor(f.Name)
}

func (f *Format) ToMarkdown() string {
	return ufmt.Sprintf("%s **|** %d **min |** %d-%d **speakers**\n\n", f.Name, f.Duration, f.MinSpeakers, f.MaxSpeakers)
}

func (f *Format) ToJson() string {
	json := "{\n"
	json += ufmt.Sprintf("  \"Name\": \"%s\",\n", f.Name)
	json += ufmt.Sprintf("  \"Description\": \"%s\",\n", f.Description)
	json += ufmt.Sprintf("  \"Duration\": %d,\n", f.Duration)
	json += ufmt.Sprintf("  \"MinSpeakers\": %d,\n", f.MinSpeakers)
	json += ufmt.Sprintf("  \"MaxSpeakers\": %d\n", f.MaxSpeakers)
	json += "}"
	return json
}

func (f *Format) ToSVG() string {
	y := 40
	fragment := f.ToSVGFragment(&y)
	height := ufmt.Sprintf("%d", y)
	svg := component.SvgHeading("1000", height) + fragment + "</svg>"
	return svg
}

func (f *Format) ToSVGFragment(y *int) string {
	summary := ufmt.Sprintf("%s | %d min | %d–%d speakers", f.Name, f.Duration, f.MinSpeakers, f.MaxSpeakers)
	svg := component.RenderSVGLine(y, "text", "Format:", summary)
	svg += component.RenderSVGLine(y, "text", "", f.Description)
	return svg
}

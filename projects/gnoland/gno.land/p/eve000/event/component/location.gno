package component

import (
	"net/url"
	"strings"

	"gno.land/p/demo/ufmt"
)

type Location struct {
	Name        string
	Address     string
	Coordinates string
	Description string
	renderOpts  map[string]interface{} // TODO: consider exposing this in every component
}

var _ Component = (*Location)(nil)

func (l *Location) SetName(name string) {
	l.Name = name
}

func (l *Location) SetAddress(address string) {
	l.Address = address
}

func (l *Location) SetCoordinates(coordinates string) {
	l.Coordinates = coordinates
}

func (l *Location) SetDescription(description string) {
	l.Description = description
}

func (l *Location) ToAnchor() string {
	return StringToAnchor(l.Name)
}

func (l *Location) ToMarkdown(_ ...Content) string {
	md := "### " + l.Name + "\n"
	if l.Address != "" {
		md += "\n [" + l.Address + "](https://www.google.com/maps/search/?api=1&query=" + url.QueryEscape(l.Address) + ")\n"
	}
	if l.Coordinates != "" {
		coords := strings.ReplaceAll(l.Coordinates, " ", "")
		md += "\n [Coordinates " + coords + "](https://www.google.com/maps/?q=" + coords + ")\n"
	}
	if l.Description != "" {
		md += "\n\n" + l.Description + "\n"
	}
	// REVIEW: would be nice to have a way to link to a location on a map
	return md
}

func (l *Location) ToJson() string {
	json := "{\n"
	json += "  \"Name\":\"" + l.Name + "\"\n"
	if l.Address != "" {
		json += ",\n"
		json += "  \"Address\":\"" + l.Address + "\"\n"
	}
	if l.Coordinates != "" {
		json += ",\n"
		json += "  \"Coordinates\":\"" + l.Coordinates + "\"\n"
	}
	json += "}"
	return json
}

func (l *Location) ToSVG() string {
	y := 40
	fragment := l.ToSVGFragment(&y)
	height := ufmt.Sprintf("%d", y+20)
	return SvgHeading("600", height) + fragment + "</svg>"
}

func (l *Location) ToSVGFragment(y *int) string {
	svg := "<g class=\"location\">"
	svg += RenderSVGLine(y, "sessiontitle", "", l.Name)
	svg += RenderSVGLine(y, "text", "", l.Address)
	svg += RenderSVGLine(y, "text", "", l.Coordinates)
	svg += RenderSVGLine(y, "text", "", l.Description)
	svg += "</g>"
	return svg
}

func (l *Location) ToSvgDataUrl() string {
	return "data:image/svg+xml;utf8," + url.PathEscape(l.ToSVG())
}

func (l *Location) RenderOpts() map[string]interface{} {
	return l.renderOpts
}

func (s *Location) SetRenderOpts(ro map[string]interface{}) {
	s.renderOpts = ro
}

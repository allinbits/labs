package speaker

import (
	"net/url"

	"gno.land/p/demo/ufmt"
	"gno.land/p/eve000/event/component"
)

type Speaker struct {
	Name        string
	Biography   string
	Affiliation string
	PictureURL  string
	Tags        []string
	renderOpts  *component.RenderOpts
}

var _ component.Component = (*Speaker)(nil)

func (s *Speaker) SetName(name string) {
	s.Name = name
}

func (s *Speaker) SetBiography(biography string) {
	s.Biography = biography
}

func (s *Speaker) SetAffiliation(affiliation string) {
	s.Affiliation = affiliation
}

func (s *Speaker) SetPictureURL(pictureURL string) {
	s.PictureURL = pictureURL
}

func (s *Speaker) SetTags(tags []string) {
	s.Tags = tags
}

// REVIEW do tags and renderOpts need setters?

func (s *Speaker) ToAnchor() string {
	return component.StringToAnchor(s.Name)
}

func (s *Speaker) ToMarkdown() string {
	markdown := "#### " + s.Name + "\n\n"
	if s.Biography != "" {
		markdown += s.Biography + "\n\n"
	}
	if s.Affiliation != "" {
		markdown += "Affiliation: " + s.Affiliation + "\n\n"
	}
	if s.PictureURL != "" {
		markdown += "![Picture](" + s.PictureURL + ")\n\n"
	}
	if len(s.Tags) > 0 {
		markdown += "Tags: "
		for i, tag := range s.Tags {
			if i > 0 {
				markdown += ", "
			}
			markdown += component.LinkTag(tag)
		}
		markdown += "\n\n"
	}
	return markdown
}

func (s *Speaker) ToJson() string {
	json := "{\n"
	json += "  \"Name\":\"" + s.Name + "\""

	if s.Biography != "" {
		json += ",\n  \"Biography\":\"" + s.Biography + "\""
	}
	if s.Affiliation != "" {
		json += ",\n  \"Affiliation\":\"" + s.Affiliation + "\""
	}
	if s.PictureURL != "" {
		json += ",\n  \"PictureURL\":\"" + s.PictureURL + "\""
	}

	json += "\n}"
	return json
}

func (s *Speaker) ToSVG() string {
	y := 40
	fragment := s.ToSVGFragment(&y)
	height := ufmt.Sprintf("%d", y+20)
	return component.SvgHeading("600", height) + fragment + "</svg>"
}

func (s *Speaker) ToSVGFragment(y *int) string {
	svg := "<g class=\"speaker\">"
	svg += component.RenderSVGLine(y, "speaker", "", s.Name)
	svg += component.RenderSVGLine(y, "text", "", s.Biography)
	svg += component.RenderSVGLine(y, "text", "", s.Affiliation)
	/* REVIEW: do we expect nested image refs to work? do we need to set a specific schema in svg header?
	   if s.PictureURL != "" {
	       y += 20
	       svg += "<image x=\"20\" y=\"" + ufmt.Sprintf("%d", y) + "\" width=\"100\" height=\"100\" href=\"" + s.PictureURL + "\"/>"
	   }
	*/
	svg += "</g>"
	return svg
}

func (s *Speaker) ToSvgDataUrl() string {
	return "data:image/svg+xml;utf8," + url.PathEscape(s.ToSVG())
}

func (s *Speaker) RenderOpts() *component.RenderOpts {
	return s.renderOpts
}

func (s *Speaker) SetRenderOpts(ro *component.RenderOpts) {
	s.renderOpts = ro
}

func (s *Speaker) HasTag(tag string) bool {
	for _, t := range s.Tags {
		if t == tag {
			return true
		}
	}
	return false
}

func (s *Speaker) AddTags(tags []string) {
	for _, t := range tags {
		if !s.HasTag(t) {
			s.Tags = append(s.Tags, t)
		}
	}
}

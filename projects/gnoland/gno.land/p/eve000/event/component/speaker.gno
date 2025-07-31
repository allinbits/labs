package component

import (
	"net/url"

	"gno.land/p/demo/ufmt"
)

type Speaker struct {
	Name        string
	Address     string
	Biography   string
	Affiliation string
	PictureURL  string
	renderOpts  map[string]interface{}
}

var _ Component = (*Speaker)(nil)

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

func (s *Speaker) ToAnchor() string {
	return StringToAnchor(s.Name)
}

func (s *Speaker) ToMarkdown(_ ...Content) string {
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
	if s.Address != "" {
		markdown += "Address: [" + s.Address + "]( /u/" + s.Address + ")\n\n"
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
	return SvgHeading("600", height) + fragment + "</svg>"
}

func (s *Speaker) ToSVGFragment(y *int) string {
	svg := "<g class=\"speaker\">"
	svg += RenderSVGLine(y, "speaker", "", s.Name)
	svg += RenderSVGLine(y, "text", "", s.Biography)
	svg += RenderSVGLine(y, "text", "", s.Affiliation)
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

func (s *Speaker) RenderOpts() map[string]interface{} {
	return s.renderOpts
}

func (s *Speaker) SetRenderOpts(ro map[string]interface{}) {
	s.renderOpts = ro
}

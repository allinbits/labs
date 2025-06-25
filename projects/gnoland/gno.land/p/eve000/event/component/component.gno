package component

import (
	"net/url"
	"strconv"
	"strings"
	"time"

	"gno.land/p/demo/ufmt"
)

const DtFmt = "Mon Jan 2"

type Component interface {
	ToAnchor() string
	ToMarkdown() string // REVIEW: should we allow filtering?
	ToJson() string
	ToSVG() string
	ToSvgDataUrl() string
	RenderOpts() *RenderOpts
}

// RenderOpts is a "feature flag" struct for controlling the rendering of components.
// It allows for selective rendering of different parts of a component.
// REVIEW: consider using a new set of render opts per event rather than 1-per-registry as it is now
type RenderOpts struct {
	Svg      bool
	Schedule bool
	Location bool
	Speaker  bool
}

func RenderComponent(path string, c Component) (out string) {
	var sb strings.Builder

	if c == nil {
		return ""
	}

	u, err := url.Parse(path)
	if err != nil {
		panic("invalid path in RenderComponent: " + path)
	}

	switch u.Query().Get("format") {
	case "json":
		sb.WriteString("```json\n" + c.ToJson() + "\n```")
	case "frame":
		sb.WriteString("```gnomark\n" + c.ToJson() + "\n```")
	default:
		sb.WriteString(c.ToMarkdown())
	}

	if c.RenderOpts().Svg {
		dataURL := c.ToSvgDataUrl()
		anchor := c.ToAnchor()
		sb.WriteString("\n[![" + anchor + "](" + dataURL + ")](" + anchor + ")\n\n---\n\n")
	}

	return sb.String()
}

// Content is a user-editable content struct.
type Content struct {
	Published bool
	Markdown  string
}

func (c *Content) SetPublished(published bool) {
	c.Published = published
}

func (c *Content) SetMarkdown(markdown string) {
	c.Markdown = markdown
}

func StringToAnchor(text string) string {
	text = strings.ToLower(text)
	text = strings.ReplaceAll(text, " ", "-")
	text = strings.ReplaceAll(text, ".", "")
	text = strings.ReplaceAll(text, ",", "")
	text = strings.ReplaceAll(text, ":", "")
	text = strings.ReplaceAll(text, ";", "")
	text = strings.ReplaceAll(text, "!", "")
	text = strings.ReplaceAll(text, "?", "")
	return "#" + text
}

func SplitText(text string, maxLength int) []string {
	var lines []string
	for len(text) > maxLength {
		splitAt := maxLength
		for splitAt > 0 && text[splitAt] != ' ' {
			splitAt--
		}
		if splitAt == 0 {
			splitAt = maxLength
		}
		lines = append(lines, text[:splitAt])
		text = text[splitAt:]
	}
	lines = append(lines, text)
	return lines
}

func SvgHeading(width, height string) string {
	svg := "<svg width=\"" + width + "\" height=\"" + height + "\" xmlns=\"http://www.w3.org/2000/svg\">"
	svg += "<style>"
	svg += ".title { font: bold 24px sans-serif; }"
	svg += ".subtitle { font: bold 18px sans-serif; }"
	svg += ".sessiontitle { font: bold 16px sans-serif; }"
	svg += ".text { font: 14px sans-serif; }"
	svg += ".label { font: bold 14px sans-serif; }" // ✅ NEW: small bold
	svg += ".speaker { font: 14px sans-serif; font-style: italic; }"
	svg += ".session { font: 14px sans-serif; margin-top: 20px; }"
	svg += "</style>"
	return svg
}

func RenderSVGLine(y *int, class, label, text string) string {
	var svg string
	if label != "" && text != "" {
		textLines := SplitText(text, 80)
		svg += ufmt.Sprintf(`<text x="20" y="%d" class="%s"><tspan class="label">%s</tspan> %s</text>`, *y, class, label, textLines[0])
		*y += 20
		for _, line := range textLines[1:] {
			svg += ufmt.Sprintf(`<text x="20" y="%d" class="%s">%s</text>`, *y, class, line)
			*y += 20
		}
	} else if text != "" {
		textLines := SplitText(text, 80)
		for _, line := range textLines {
			svg += ufmt.Sprintf(`<text x="20" y="%d" class="%s">%s</text>`, *y, class, line)
			*y += 20
		}
	}
	return svg
}

func FormatDuration(duration time.Duration) string {
	d := strings.TrimRight(duration.String(), "0s")
	if strings.HasSuffix(d, "h0m") { // e.g., "1h0m0s"
		d = strings.TrimRight(d, "0m")
	}
	return d
}

func ParseDate(t string) time.Time {
	parsedTime, err := time.Parse(time.DateOnly, t)
	if err != nil {
		panic("DateOnly format required:" + time.DateOnly)
	}
	return parsedTime
}

func ParseTime(t string) time.Time {
	parsedTime, err := time.Parse(time.RFC3339, t)
	if err != nil {
		panic("RFC3339 format required:" + time.RFC3339)
	}
	return parsedTime
}

func ParseDuration(d string) time.Duration {
	parsedDuration, err := time.ParseDuration(d)
	if err != nil {
		panic("invalid duration format")
	}
	return parsedDuration
}

func TagString(tag string) string {
	tag = strings.ToLower(tag)
	tag = strings.ReplaceAll(tag, " ", "-")
	tag = strings.ReplaceAll(tag, ".", "")
	tag = strings.ReplaceAll(tag, ",", "")
	tag = strings.ReplaceAll(tag, ":", "")
	tag = strings.ReplaceAll(tag, ";", "")
	tag = strings.ReplaceAll(tag, "!", "")
	tag = strings.ReplaceAll(tag, "?", "")
	return tag
}

func LinkTag(name string) string {
	return "[" + name + "](?tag=" + TagString(name) + ")"
}

func TagToName(tag string) string {
	tag = strings.ReplaceAll(tag, "-", " ")
	words := strings.Fields(tag)
	for i, word := range words {
		if len(word) > 0 {
			words[i] = strings.ToUpper(string(word[0])) + word[1:]
		}
	}
	return strings.Join(words, " ")
}

func IdFromPath(path string) int {
	parts := strings.Split(path, ":")
	if len(parts) < 2 {
		panic("invalid path")
	}
	id, err := strconv.Atoi(parts[1])
	if err != nil {
		panic("invalid id")
	}
	return id
}

func escapeHtml(s string) string {
	s = strings.ReplaceAll(s, "&", "&amp;")
	s = strings.ReplaceAll(s, "<", "&lt;")
	s = strings.ReplaceAll(s, ">", "&gt;")
	s = strings.ReplaceAll(s, "\"", "&quot;")
	s = strings.ReplaceAll(s, "'", "&#39;")
	return s
}

func Button(label, path string) string {
	return SubmitButton(label, path, 16, 120) // Default font size and min width
}

func SubmitButton(label, path string, fontSize, minWidth int) string {
	charWidth := int(0.6 * float64(fontSize)) // Approximate width of each character
	padding := 40                             // Total padding (left + right)
	h := 2 * fontSize                         // Height of the button, 2x font size for padding
	w := len(label)*charWidth + padding
	if w < minWidth {
		w = minWidth
	}

	svgButton := `<svg xmlns="http://www.w3.org/2000/svg" width="` + strconv.Itoa(w) + `" height="` + strconv.Itoa(h) + `">
<defs>
  <filter id="dropShadow" x="-50%" y="-50%" width="200%" height="200%">
    <feGaussianBlur in="SourceAlpha" stdDeviation="3" result="blur"/>
    <feOffset in="blur" dx="2" dy="2" result="offsetBlur"/>
    <feMerge>
      <feMergeNode in="offsetBlur"/>
      <feMergeNode in="SourceGraphic"/>
    </feMerge>
  </filter>
</defs>
<foreignObject x="16" y="-5" width="` + strconv.Itoa(w) + `" height="` + strconv.Itoa(h) + `" filter="url(#dropShadow)">
  <body xmlns="http://www.w3.org/1999/xhtml">
    <button style="padding-left: 20px; font-size:` + strconv.Itoa(fontSize) + `px">
      ` + escapeHtml(label) + `
    </button>
  </body>
</foreignObject>
</svg>`

	dataUrl := "data:image/svg+xml;utf8," + url.PathEscape(svgButton)

	return "[![" + label + "](" + dataUrl + ")](" + path + ")"
}

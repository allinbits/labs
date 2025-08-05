package component

import (
	"net/url"
	"regexp"
	"std"
	"strconv"
	"strings"
	"time"

	"gno.land/p/demo/ufmt"
	"gno.land/p/moul/txlink"
)

// Interfaces

type IcsFileProvider interface {
	ToIcs() string // returns the content of the ICS file
}

type ContentProvider interface {
	Render(path ...string) string
}

type JsonLdProvider interface {
	ToJsonLD() string // schema.org compatible
}

type JsonProvider interface {
	ToJson() string
}

type MarkdownProvider interface {
	ToMarkdown(...Content) string
}

type Component interface {
	ToAnchor() string
	ToMarkdown(...Content) string
	ToJson() string // freeform JSON representation
	ToSVG() string
	ToSvgDataUrl() string
	RenderOpts() map[string]interface{}
}

// Types

type EventStatus string
type EventAttendanceMode string

type Content struct {
	Published bool
	Markdown  string
	Callback  func(string) string
}

// Constants

const DtFmt = "Mon Jan 2"

const (
	EventScheduled   EventStatus = "https://schema.org/EventScheduled"
	EventCancelled   EventStatus = "https://schema.org/EventCancelled"
	EventMovedOnline EventStatus = "https://schema.org/EventMovedOnline"
	EventPostponed   EventStatus = "https://schema.org/EventPostponed"
	EventRescheduled EventStatus = "https://schema.org/EventRescheduled"
)

const (
	OfflineEventAttendanceMode EventAttendanceMode = "https://schema.org/OfflineEventAttendanceMode"
	OnlineEventAttendanceMode  EventAttendanceMode = "https://schema.org/OnlineEventAttendanceMode"
	MixedEventAttendanceMode   EventAttendanceMode = "https://schema.org/MixedEventAttendanceMode"
)

// Content Methods

func (c *Content) SetPublished(published bool) {
	c.Published = published
}

func (c *Content) SetMarkdown(markdown string) {
	c.Markdown = markdown
}

func (c *Content) Render(path ...string) string {
	if !c.Published || (c.Markdown == "" && c.Callback == nil) {
		return ""
	}
	if c.Callback != nil {
		if len(path) > 0 {
			return c.Callback(path[0])
		}
		return c.Callback("")
	}
	return c.Markdown
}

// Rendering Functions

func RenderPage(path string, c interface{}, body ...Content) string {
	q := ParseQuery(path)
	format := q.Get("format")

	if c == nil {
		panic("RenderPage: component is nil")
	}

	switch {
	case format == "ics" && implementsIcsFileProvider(c):
		return renderIcsFile(c, body)
	case format == "json" && implementsJsonProvider(c):
		return renderJson(c, body)
	case format == "jsonld" && implementsJsonLdProvider(c):
		return renderJsonLd(c, body)
	case implementsContentProvider(c):
		return c.(ContentProvider).Render(path)
	case implementsMarkdownProvider(c):
		return c.(MarkdownProvider).ToMarkdown(body...)
	default:
		panic("RenderPage: unsupported type")
	}
}

func RenderComponent(path string, c Component) string {
	if c == nil {
		return ""
	}

	u, err := url.Parse(path)
	if err != nil {
		panic("invalid path in RenderComponent: " + path)
	}

	var sb strings.Builder
	switch u.Query().Get("format") {
	case "json":
		sb.WriteString("```json\n" + c.ToJson() + "\n```")
	case "frame":
		sb.WriteString(c.ToJson())
	default:
		sb.WriteString(c.ToMarkdown())
	}

	sb.WriteString("\n[![" + c.ToAnchor() + "](" + c.ToSvgDataUrl() + ")](" + c.ToAnchor() + ")\n\n---\n\n")
	return sb.String()
}

// Utility Functions

func StringToAnchor(text string) string {
	return "#" + slugify(text)
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
	return `<svg width="` + width + `" height="` + height + `" xmlns="http://www.w3.org/2000/svg">
<style>
.title { font: bold 24px sans-serif; }
.subtitle { font: bold 18px sans-serif; }
.sessiontitle { font: bold 16px sans-serif; }
.text { font: 14px sans-serif; }
.label { font: bold 14px sans-serif; }
.speaker { font: 14px sans-serif; font-style: italic; }
.session { font: 14px sans-serif; margin-top: 20px; }
</style>`
}

func RenderSVGLine(y *int, class, label, text string) string {
	var svg string
	textLines := SplitText(text, 80)
	if label != "" && len(textLines) > 0 {
		svg += ufmt.Sprintf(`<text x="20" y="%d" class="%s"><tspan class="label">%s</tspan> %s</text>`, *y, class, label, textLines[0])
		*y += 20
		textLines = textLines[1:]
	}
	for _, line := range textLines {
		svg += ufmt.Sprintf(`<text x="20" y="%d" class="%s">%s</text>`, *y, class, line)
		*y += 20
	}
	return svg
}

func FormatDuration(duration time.Duration) string {
	d := strings.TrimRight(duration.String(), "0s")
	if strings.HasSuffix(d, "h0m") {
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
	return slugify(tag)
}

func LinkTag(name string) string {
	return "[" + name + "](?tag=" + TagString(name) + ")"
}

func ParseQuery(path string) url.Values {
	if len(path) > 0 && path[0] == '?' {
		u, err := url.Parse(std.CurrentRealm().PkgPath() + path)
		if err == nil {
			return u.Query()
		}
	}
	return url.Values{}
}

func EscapeHtml(s string) string {
	replacements := map[string]string{
		"&":  "&amp;",
		"<":  "&lt;",
		">":  "&gt;",
		"\"": "&quot;",
		"'":  "&#39;",
	}
	for old, new := range replacements {
		s = strings.ReplaceAll(s, old, new)
	}
	return s
}

func TxlinkButton(label, method string) string {
	return Button(label, txlink.NewLink(method).URL())
}

func Button(label, path string) string {
	return SubmitButton(label, path, 16, 120)
}

func SubmitButton(label, path string, fontSize, minWidth int) string {
	charWidth := int(0.6 * float64(fontSize))
	padding := 40
	h := 2 * fontSize
	w := len(label)*charWidth + padding
	if w < minWidth {
		w = minWidth
	}

	svgButton := `<svg xmlns="http://www.w3.org/2000/svg" width="` + strconv.Itoa(w) + `" height="` + strconv.Itoa(h) + `">
<foreignObject x="16" y="-5" width="` + strconv.Itoa(w) + `" height="` + strconv.Itoa(h) + `">
  <body xmlns="http://www.w3.org/1999/xhtml">
    <button style="padding-left: 20px; font-size:` + strconv.Itoa(fontSize) + `px">
      ` + EscapeHtml(label) + `
    </button>
  </body>
</foreignObject>
</svg>`

	dataUrl := "data:image/svg+xml;utf8," + url.PathEscape(svgButton)
	return "[![" + label + "](" + dataUrl + ")](" + path + ")"
}

func slugify(s string) string {
	re := regexp.MustCompile(`[^a-z0-9]+`)
	return strings.Trim(re.ReplaceAllString(strings.ToLower(s), "-"), "-")
}

func Pad3(val interface{}) string {
	var s string
	switch v := val.(type) {
	case string:
		s = v
	case int:
		s = strconv.Itoa(v)
	case int64:
		s = strconv.FormatInt(v, 10)
	default:
		panic("Pad3: unsupported type")
	}
	for len(s) < 3 {
		s = "0" + s
	}
	return s
}

func FormatDate(date time.Time) string {
	if date.IsZero() {
		return ""
	}
	return date.Format(DtFmt)
}

// Helper Functions

func implementsIcsFileProvider(c interface{}) bool {
	_, ok := c.(IcsFileProvider)
	return ok
}

func implementsJsonProvider(c interface{}) bool {
	_, ok := c.(JsonProvider)
	return ok
}

func implementsJsonLdProvider(c interface{}) bool {
	_, ok := c.(JsonLdProvider)
	return ok
}

func implementsContentProvider(c interface{}) bool {
	_, ok := c.(ContentProvider)
	return ok
}

func implementsMarkdownProvider(c interface{}) bool {
	_, ok := c.(MarkdownProvider)
	return ok
}

func renderBody(body []Content) string {
	var sb strings.Builder
	for _, content := range body {
		if content.Published {
			sb.WriteString("\n\n" + content.Render() + "\n\n")
			sb.WriteString("---\n\n")
		}
	}
	return sb.String()
}

func renderIcsFile(c interface{}, body []Content) string {
	var sb strings.Builder
	sb.WriteString("```ics\n" + c.(IcsFileProvider).ToIcs() + "\n```")
	sb.WriteString(renderBody(body))
	return sb.String()
}

func renderJsonLD(c interface{}, body []Content) string {
	var sb strings.Builder
	sb.WriteString("```jsonld\n" + c.(JsonLdProvider).ToJsonLD() + "\n```")
	sb.WriteString(renderBody(body))
	return sb.String()
}

// Show data as Json next to the body content:w
func renderJson(c interface{}, body []Content) string {
	var sb strings.Builder
	sb.WriteString("```\n\n" + c.(JsonProvider).ToJson() + "\n\n```")
	sb.WriteString(renderBody(body))
	return sb.String()
}

// Show JsonLD next to the body content
func renderJsonLd(c interface{}, body []Content) string {
	var sb strings.Builder
	sb.WriteString("```\n" + c.(JsonLdProvider).ToJsonLD() + "\n```")
	sb.WriteString(renderBody(body))
	return sb.String()
}

func GetQueryParam(q url.Values, param string) (string, bool) {
	if values, ok := q[param]; ok && len(values) > 0 {
		return values[0], true
	}
	return "", false
}

func HasQueryParam(q url.Values, param string) bool {
	if values, ok := q[param]; ok && len(values) > 0 {
		return true
	}
	return false
}

func QueryValues(fullURL string) url.Values {
	u, err := url.Parse(fullURL)
	if err != nil {
		panic("Error Parsing URL")
	}
	return u.Query()
}

package proposal

import (
	"strings"

	"gno.land/p/demo/ufmt"
	"gno.land/p/eve000/event/component"
	"gno.land/p/moul/txlink"
)

type Topic struct {
	Name        string
	Description string
	Subtopics   []string
}

func RenderTopics(path string, topics map[string]Topic) string {
	var b strings.Builder

	b.WriteString("## Proposal Topics\n\n")
	for _, t := range topics {
		b.WriteString(t.ToMarkdown())
		b.WriteString(ufmt.Sprintf("[Submit a *%s* Proposal](%v)\n\n",
			t.Name, txlink.NewLink("SubmitProposal").AddArgs("topic", t.Name).URL()))
	}

	return b.String()
}

func (t *Topic) ToAnchor() string {
	return component.StringToAnchor(t.Name)
}

func (t *Topic) ToMarkdown() string {
	var sb strings.Builder
	sb.WriteString(ufmt.Sprintf("### %s\n\n%s\n\n", t.Name, t.Description))
	if len(t.Subtopics) > 0 {
		for _, sub := range t.Subtopics {
			sb.WriteString(ufmt.Sprintf("- %s\n", sub))
		}
		sb.WriteString("\n")
	}
	return sb.String()
}

func (t *Topic) ToJson() string {
	json := "{\n"
	json += ufmt.Sprintf("  \"Name\": \"%s\",\n", t.Name)
	json += ufmt.Sprintf("  \"Description\": \"%s\",\n", t.Description)
	json += "  \"Subtopics\": [\n"
	for i, sub := range t.Subtopics {
		comma := ","
		if i == len(t.Subtopics)-1 {
			comma = ""
		}
		json += ufmt.Sprintf("    \"%s\"%s\n", sub, comma)
	}
	json += "  ]\n"
	json += "}"
	return json
}

func (t *Topic) ToSVG() string {
	y := 40
	fragment := t.ToSVGFragment(&y)
	height := ufmt.Sprintf("%d", y)
	svg := component.SvgHeading("1000", height) + fragment + "</svg>"
	return svg
}

func (t *Topic) ToSVGFragment(y *int) string {
	var svg string
	svg += component.RenderSVGLine(y, "text", t.Name, "")
	svg += component.RenderSVGLine(y, "text", "", t.Description)
	for _, sub := range t.Subtopics {
		svg += component.RenderSVGLine(y, "text", "- "+sub, "")
	}
	return svg
}

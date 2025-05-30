package proposal

import (
	"net/url"
	"strings"

	"gno.land/p/demo/ufmt"
	"gno.land/p/eve000/event/component"
	"gno.land/p/moul/txlink"
)

type State int

const (
	Submitted State = iota
	Reviewed
	Approved
)

type Proposal interface {
	GetTitle() string
	SetTitle(title string)
	GetAbstract() string
	SetAbstract(abstract string)
	GetTopic() Topic
	SetTopic(topic Topic)
	GetSpeaker() string
	SetSpeaker(speaker string)
	GetOwner() string
	GetState() State
	SetRenderOpts(*component.RenderOpts)
	ToAnchor() string
	ToMarkdown() string
	ToJson() string
	ToSVG() string
	ToSvgDataUrl() string
	RenderOpts() *component.RenderOpts
}

type SubmittedProposal struct {
	Title      string
	Abstract   string
	Topic      Topic
	Speaker    string
	Owner      string
	renderOpts *component.RenderOpts
}

type ReviewedProposal struct {
	SubmittedProposal
	Comments string
	Score    int
	Reviewer string
}

type ApprovedProposal struct {
	ReviewedProposal
	ApprovedBy string
}

func RenderProposals(path string, proposals []Proposal) string {
	var (
		approvedRender  strings.Builder
		reviewedRender  strings.Builder
		submittedRender strings.Builder
	)

	for _, p := range proposals {
		switch p.GetState() {
		case Approved:
			approvedRender.WriteString(component.RenderComponent(path, p))
		case Reviewed:
			reviewedRender.WriteString(component.RenderComponent(path, p))
			reviewedRender.WriteString(component.Button("Approve Proposal",
				txlink.NewLink("ApproveProposal").AddArgs("title", p.GetTitle()).URL()) + "\n\n")
		case Submitted:
			submittedRender.WriteString(component.RenderComponent(path, p))
			submittedRender.WriteString(component.Button("Review Proposal",
				txlink.NewLink("ReviewProposal").AddArgs("title", p.GetTitle()).URL()) + "\n\n")
		}
	}

	var render strings.Builder

	render.WriteString("## Approved Proposals\n\n")
	render.WriteString(approvedRender.String())
	render.WriteString(component.Button("Export Approved Proposals",
		txlink.NewLink("ExportApprovedProposals").URL()) + "\n\n")

	render.WriteString("## Reviewed Proposals\n\n")
	render.WriteString(reviewedRender.String())

	render.WriteString("## Submitted Proposals\n\n")
	render.WriteString(submittedRender.String())

	return render.String()
}

// ========== Component Methods ==========

func (sp *SubmittedProposal) GetTitle() string               { return sp.Title }
func (sp *SubmittedProposal) SetTitle(title string)          { sp.Title = title }
func (sp *SubmittedProposal) GetAbstract() string            { return sp.Abstract }
func (sp *SubmittedProposal) SetAbstract(abstract string)    { sp.Abstract = abstract }
func (sp *SubmittedProposal) GetTopic() Topic                { return sp.Topic }
func (sp *SubmittedProposal) SetTopic(topic Topic)           { sp.Topic = topic }
func (sp *SubmittedProposal) GetSpeaker() string             { return sp.Speaker }
func (sp *SubmittedProposal) SetSpeaker(speaker string)      { sp.Speaker = speaker }
func (sp *SubmittedProposal) GetOwner() string               { return sp.Owner }
func (rp *ReviewedProposal) GetComments() string             { return rp.Comments }
func (rp *ReviewedProposal) SetComments(comments string)     { rp.Comments = comments }
func (rp *ReviewedProposal) GetScore() int                   { return rp.Score }
func (rp *ReviewedProposal) SetScore(score int)              { rp.Score = score }
func (rp *ReviewedProposal) GetReviewer() string             { return rp.Reviewer }
func (rp *ReviewedProposal) SetReviewer(reviewer string)     { rp.Reviewer = reviewer }
func (ap *ApprovedProposal) GetApprovedBy() string           { return ap.ApprovedBy }
func (ap *ApprovedProposal) SetApprovedBy(approvedBy string) { ap.ApprovedBy = approvedBy }

func (sp *SubmittedProposal) SetRenderOpts(opts *component.RenderOpts) { sp.renderOpts = opts }

func (sp *SubmittedProposal) GetState() State { return Submitted }
func (rp *ReviewedProposal) GetState() State  { return Reviewed }
func (ap *ApprovedProposal) GetState() State  { return Approved }

func (sp *SubmittedProposal) ToAnchor() string { return component.StringToAnchor(sp.Title) }
func (rp *ReviewedProposal) ToAnchor() string  { return rp.SubmittedProposal.ToAnchor() }
func (ap *ApprovedProposal) ToAnchor() string  { return ap.ReviewedProposal.ToAnchor() }

func (sp *SubmittedProposal) ToMarkdown() string {
	return ufmt.Sprintf(
		"### %s\n\n **Speaker:** %s\n\n **Topic:** %s\n\n **Abstract:** %s\n\n",
		sp.Title, sp.Speaker, sp.GetTopic().Name, sp.Abstract,
	)
}

func (rp *ReviewedProposal) ToMarkdown() string {
	md := rp.SubmittedProposal.ToMarkdown()
	md += ufmt.Sprintf("**Comments:** %s\n\n**Score:** %d\n\n**Reviewer:** %s\n\n",
		rp.Comments, rp.Score, rp.Reviewer)
	return md
}

func (ap *ApprovedProposal) ToMarkdown() string {
	return ap.ReviewedProposal.ToMarkdown() + ufmt.Sprintf("**Approved by:** %s\n\n", ap.ApprovedBy)
}

func (sp *SubmittedProposal) ToJson() string {
	json := "{\n"
	json += "  \"Title\": \"" + sp.Title + "\""
	json += ",\n  \"Speaker\": \"" + sp.Speaker + "\""
	json += ",\n  \"Topic\": \"" + sp.Topic.ToJson() + "\""
	json += ",\n  \"Description\": \"" + sp.Abstract + "\""
	json += "\n}"
	return json
}

func (rp *ReviewedProposal) ToJson() string {
	submittedJson := rp.SubmittedProposal.ToJson()
	submittedJson = strings.TrimRight(submittedJson, "}")

	json := "{\n"
	json += "  \"SubmittedProposal\": " + submittedJson + ",\n"
	json += "  \"Comments\": \"" + rp.Comments + "\",\n"
	json += "  \"Score\": " + ufmt.Sprintf("%d", rp.Score) + ",\n"
	json += "  \"Reviewer\": \"" + rp.Reviewer + "\",\n"
	json += "  \"State\": \"Reviewed\"\n"
	json += "}"
	return json
}

func (ap *ApprovedProposal) ToJson() string {
	reviewedJson := ap.ReviewedProposal.ToJson()
	reviewedJson = strings.TrimRight(reviewedJson, "}")

	json := "{\n"
	json += "  \"ReviewedProposal\": " + reviewedJson + ",\n"
	json += "  \"ApprovedBy\": \"" + ap.ApprovedBy + "\",\n"
	json += "  \"State\": \"Approved\"\n"
	json += "}"
	return json
}

func (sp *SubmittedProposal) ToSVG() string {
	y := 40
	fragment := sp.ToSVGFragment(&y)
	height := ufmt.Sprintf("%d", y+20)
	svg := component.SvgHeading("1000", height) + fragment + "</svg>"
	return svg
}

func (rp *ReviewedProposal) ToSVG() string {
	y := 40
	fragment := rp.ToSVGFragment(&y)
	height := ufmt.Sprintf("%d", y+20)
	svg := component.SvgHeading("1000", height) + fragment + "</svg>"
	return svg
}

func (ap *ApprovedProposal) ToSVG() string {
	y := 40
	fragment := ap.ToSVGFragment(&y)
	height := ufmt.Sprintf("%d", y+20)
	svg := component.SvgHeading("1000", height) + fragment + "</svg>"
	return svg
}

func (sp *SubmittedProposal) ToSVGFragment(y *int) string {
	var svg string
	svg += component.RenderSVGLine(y, "title", "", sp.Title)
	svg += component.RenderSVGLine(y, "text", "Speaker:", sp.Speaker)

	topicText := ufmt.Sprintf("%s | %s", sp.Topic.Name, sp.Topic.Description)
	svg += component.RenderSVGLine(y, "text", "Topic:", topicText)
	svg += component.RenderSVGLine(y, "text", "Abstract:", sp.Abstract)

	return svg
}

func (rp *ReviewedProposal) ToSVGFragment(y *int) string {
	svg := rp.SubmittedProposal.ToSVGFragment(y)
	svg += component.RenderSVGLine(y, "text", "Comments:", rp.Comments)
	svg += component.RenderSVGLine(y, "text", "Score:", ufmt.Sprintf("%d", rp.Score))
	svg += component.RenderSVGLine(y, "text", "Reviewed by:", rp.Reviewer)

	return svg
}

func (ap *ApprovedProposal) ToSVGFragment(y *int) string {
	svg := ap.ReviewedProposal.ToSVGFragment(y)
	svg += component.RenderSVGLine(y, "text", "Approved by:", ap.ApprovedBy)

	return svg
}

func (sp *SubmittedProposal) ToSvgDataUrl() string {
	return "data:image/svg+xml;utf8," + url.PathEscape(sp.ToSVG())
}

func (sp *SubmittedProposal) RenderOpts() *component.RenderOpts {
	return sp.renderOpts
}

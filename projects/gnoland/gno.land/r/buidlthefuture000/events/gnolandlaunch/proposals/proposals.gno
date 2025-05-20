package proposals

import (
	"std"
	"strconv"
	"strings"

	event "gno.land/r/buidlthefuture000/events/gnolandlaunch"

	"gno.land/p/demo/ufmt"
	"gno.land/p/eve000/event/component"
	"gno.land/p/eve000/event/proposal"
)

// Header for your Call for Proposals Realm
var ProposalsRealmHeader = "# BTF 2025 Call for Proposals\n\n"

// BTF 2025 FORMAT TYPES
var ValidFormats = map[string]proposal.Format{
	"Panel":         {"Panel", "A group discussion moderated by a facilitator.", 90, 2, 5},
	"Lecture":       {"Lecture", "An educational talk to an audience, typically by an expert.", 60, 1, 1},
	"Fireside Chat": {"Fireside Chat", "An informal yet structured interview or conversation.", 45, 1, 2},
}

var opts = &component.RenderOpts{
	Location: true,
	Svg:      false,
	Schedule: true,
	Speaker:  false,
}

// Initial proposals
var proposals = []proposal.Proposal{
	&proposal.SubmittedProposal{
		Title:    "Open Community Proposal Spot #1",
		Abstract: "This is spot 1 of 2 open for community presentations for the Build The Future Launch Event.",
		Format:   ValidFormats["Fireside Chat"],
		Speaker:  "Community Proposal Spot #1 Speaker(s)",
	},
	&proposal.ReviewedProposal{
		SubmittedProposal: proposal.SubmittedProposal{
			Title:    "Open Community Proposal Spot #2",
			Abstract: "This is 2 of 2 spots open for community presentations for the Build The Future Launch Event.",
			Format:   ValidFormats["Panel"],
			Speaker:  "Community Proposal Spot #2 Speaker(s)",
		},
		Comments: "For the purposes of the demo, this proposal has been \"reviewed\". And this is a review comment.",
		Score:    10,
		Reviewer: "Community Proposal Spot #2 Reviewer(s)",
	},
}

func init() {
	for _, p := range proposals {
		p.SetRenderOpts(opts)
	}
}

// Render generates the full text output for the event
func Render(path string) string {
	var out strings.Builder
	out.WriteString(ProposalsRealmHeader)
	out.WriteString(proposal.RenderProposals(path, proposals))
	// out.WriteString(proposal.RenderFormats(path, ValidFormats))
	return out.String()
}

//      ACL HEIRARCHY
//        Organizer
//        approve
//        export
//       /        \
//      v         v
//    Proposer   Reviewer
//    submit     review
//    edit

// --- API-Like Endpoints ---

func SubmitProposal(title, abstract, formatName, speaker string) {
	event.AssertAtLeastRole("proposer", std.OriginCaller())
	if format, ok := ValidFormats[formatName]; ok {
		sp := &proposal.SubmittedProposal{
			Title:    title,
			Abstract: abstract,
			Format:   format,
			Speaker:  speaker,
		}
		sp.SetRenderOpts(opts) // <-- Explicitly set after creation

		proposals = append(proposals, sp)
	}
}

func ReviewProposal(title, comments, reviewer string, score int) {
	event.AssertAtLeastRole("reviewer", std.OriginCaller())
	for i, p := range proposals {
		if p.GetTitle() == title {
			if sp, ok := p.(*proposal.SubmittedProposal); ok {
				proposals[i] = &proposal.ReviewedProposal{
					SubmittedProposal: *sp,
					Comments:          comments,
					Reviewer:          reviewer,
					Score:             score,
				}
			}
			return
		}
	}
}

func ApproveProposal(title, approver string) {
	crossing()
	event.AssertAtLeastRole("organizer", std.OriginCaller())
	for i, p := range proposals {
		if p.GetTitle() == title {
			if rp, ok := p.(*proposal.ReviewedProposal); ok {
				proposals[i] = &proposal.ApprovedProposal{
					ReviewedProposal: *rp,
					ApprovedBy:       approver,
				}
			}
			return
		}
	}
}

func ApproveProposals(titles []string, approver string) {
	event.AssertAtLeastRole("organizer", std.OriginCaller())
	for _, title := range titles {
		ApproveProposal(title, approver)
	}
}

func EditProposal(title, key, value string) error {
	crossing()
	for _, p := range proposals {
		if p.GetTitle() != title {
			continue
		}

		if !(event.HasRole("proposer", std.OriginCaller()) && std.OriginCaller().String() == p.GetOwner()) {
			return ufmt.Errorf("unauthorized: %q may not edit %q", std.OriginCaller(), p.GetTitle())
		}

		switch strings.ToLower(key) {
		case "title":
			p.SetTitle(value)

		case "abstract":
			p.SetAbstract(value)

		case "speaker":
			p.SetSpeaker(value)

		case "format":
			if fmtVal, ok := ValidFormats[value]; ok {
				p.SetFormat(fmtVal)
			} else {
				return ufmt.Errorf("unknown format %q", value)
			}

		case "comments":
			if rp, ok := p.(*proposal.ReviewedProposal); ok {
				rp.SetComments(value)
			} else {
				return ufmt.Errorf("proposal %q is not in Reviewed state", title)
			}

		case "score":
			if rp, ok := p.(*proposal.ReviewedProposal); ok {
				i, err := strconv.Atoi(value)
				if err != nil {
					return ufmt.Errorf("invalid score %q: %w", value, err)
				}
				rp.SetScore(i)
			} else {
				return ufmt.Errorf("proposal %q is not in Reviewed state", title)
			}

		case "reviewer":
			if rp, ok := p.(*proposal.ReviewedProposal); ok {
				rp.SetReviewer(value)
			} else {
				return ufmt.Errorf("proposal %q is not in Reviewed state", title)
			}

		case "approvedby":
			if ap, ok := p.(*proposal.ApprovedProposal); ok {
				ap.SetApprovedBy(value)
			} else {
				return ufmt.Errorf("proposal %q is not in Approved state", title)
			}

		default:
			return ufmt.Errorf("unknown field %q", key)
		}

		return nil
	}

	return ufmt.Errorf("no proposal found with title %q", title)
}

func ExportApprovedProposals() []proposal.Proposal {
	crossing()
	var approved []proposal.Proposal
	for _, p := range proposals {
		if p.GetState() == proposal.Approved {
			base := &proposal.SubmittedProposal{
				Title:    p.GetTitle(),
				Abstract: p.GetAbstract(),
				Format:   p.GetFormat(),
				Speaker:  p.GetSpeaker(),
				Owner:    p.GetOwner(),
			}
			// carry over your render opts if you want:
			base.SetRenderOpts(opts)
			approved = append(approved, base)
		}
	}
	return approved
}

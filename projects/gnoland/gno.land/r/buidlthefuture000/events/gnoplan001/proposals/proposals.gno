package proposals

import (
	"std"
	"strconv"
	"strings"
	"net/url"

	event "gno.land/r/buidlthefuture000/events/gnoplan001"

	"gno.land/p/demo/ufmt"
	"gno.land/p/eve000/event/proposal"
)

var api = &event.App{}

// TODO: try out forms here - will need to URL decode form submissions

// Header for your Call for Proposals Realm
var ProposalsRealmHeader = "# BTF 2025 Call for Proposals\n\n"

// BTF 2025 FORMAT TYPES
var EventTopics = map[string]proposal.Topic{
	"Privacy, Security & Identity": {
		Name:        "Privacy, Security & Identity",
		Description: "Exploring how we communicate, authenticate, and secure ourselves in decentralized systems.",
		Subtopics: []string{
			"Private Communication: Tools and protocols enabling encrypted, censorship-resistant messaging.",
			"Decentralized Identity and Authentication: Self-sovereign identity (DID) and wallet-based login.",
			"Digital and Real Identity: Bridging online personas with real-world identity; implications for governance, finance, and social systems.",
			"Usability and Security: Tradeoffs and innovations in designing secure yet user-friendly tools, especially for new users.",
			"The Deepfake Era: AI Scams, Identity Theft & Misinformation: The rise of AI threatens identity, truth and trust.",
		},
	},
	"Information, Media & Social Infrastructure": {
		Name:        "Information, Media & Social Infrastructure",
		Description: "Creating new platforms and discovery systems that support censorship-proof coordination and communication.",
		Subtopics: []string{
			"New Wikipedia / New Twitter / New Facebook / New Reddit: Building decentralized knowledge, social, and discourse platforms without central control. Finding the balance between moderation and censorship.",
			"Information Discovery: Rethinking accessibility, content surfacing, and truth discovery in open networks.",
			"Creating a Streaming Platform Without Relying on Anyone: Decentralized infrastructure for video and content creation, as alternatives to Big Tech.",
		},
	},
	"Governance & Regulation": {
		Name:        "Governance & Regulation",
		Description: "Examining governance at every level: local, global, digital, and how builders engage with regulators.",
		Subtopics: []string{
			"Local Governance / DAO Governance: Innovations in collective decision-making, from local to on-chain communities.",
			"Builders Talking to Regulators: Regulatory clarity, builder concerns, and how to build responsibly in Web3.",
		},
	},
	"Infrastructure, Tools & Developer UX": {
		Name:        "Infrastructure, Tools & Developer UX",
		Description: "Core building blocks of the decentralized stack: from wallets to protocols.",
		Subtopics: []string{
			"Hardware Wallets / Software Wallets / Browser Extensions: Comparison and future of key management and interaction in Web3.",
			"Web2 to Web3: Helping users and developers transition; patterns, pain points, and onboarding strategies.",
			"Cosmos ecosystem: Highlighting innovations from the Cosmos ecosystem: ecosystem-specific use cases.",
		},
	},
	"Gno.land & The Logoverse": {
		Name:        "Gno.land & The Logoverse",
		Description: "Exploring the unique vision of Gno.land as the first Logoverse.",
		Subtopics: []string{
			"Introducing Gno.land: Gno.land: the world's first viable language-based multi-user operating system.",
			"Gno.land, the Logoverse and What it Means: The hub for human and machine coordination, built to host the knowledge base of the new millennium.",
			"From Ideas to dApps: Gno.land as a Platform for Builders: How Gno.land’s architecture enables novel decentralized applications: persistent contracts, multi-user logic, and composability beyond traditional smart contracts.",
		},
	},
	"The Intersection of AI & Web3": {
		Name:        "The Intersection of AI & Web3",
		Description: "Where artificial intelligence meets decentralization.",
		Subtopics: []string{
			"AI and Blockchain: AI in the Gno.land’s Logoverse: How Gno.land can enable decentralized, transparent and auditable AI. Use cases, boundaries, and governance.",
			"Collective Intelligence in the Logoverse: Gno.land and the future of human-AI collaboration: programmable ideas, community-curated knowledge, and tools that scale collective intelligence.",
			"AI and Coding: Accelerating dApp Development: Using AI to write, test, and audit code.",
		},
	},
	"Secure Home Computing": {
		Name:        "Secure Home Computing",
		Description: "Reimagining the personal computer as a sovereign, secure, and programmable node in a decentralized network.",
		Subtopics: []string{
			"Secure-by-Design Personal Computing: Exploring the infrastructure that gives users control over their own machines and data.",
			"Your Personal Node connected to the Logoverse: Connect your local computer to the broader Logoverse: contribute, coordinate and own your data.",
		},
	},
}

var opts = map[string]interface{}{
	"Location": struct{}{},
	"Schedule": struct{}{},
}

// Initial proposals
var proposals = []proposal.Proposal{
	&proposal.SubmittedProposal{
		Title:    "Open Community Proposal Spot #1",
		Abstract: "This is spot 1 of 2 open for community presentations for the Build The Future Launch Event.",
		Topic:    EventTopics["Secure Home Computing"],
		Speaker:  "Community Proposal Spot #1 Speaker(s)",
	},
	&proposal.ReviewedProposal{
		SubmittedProposal: proposal.SubmittedProposal{
			Title:    "Open Community Proposal Spot #2",
			Abstract: "This is 2 of 2 spots open for community presentations for the Build The Future Launch Event.",
			Topic:    EventTopics["Gno.land & The Logoverse"],
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
	out.WriteString(proposal.RenderTopics(path, EventTopics))
	return out.String()
}

func SubmitProposal(title, abstract, topic, speaker string) {
    title, _ = url.QueryUnescape(title)
    topic, _ = url.QueryUnescape(topic)
    speaker, _ = url.QueryUnescape(speaker)
	api.AssertAtLeastRole("proposer", std.OriginCaller())
	if topic, ok := EventTopics[topic]; ok {
		sp := &proposal.SubmittedProposal{
			Title:    title,
			Abstract: abstract,
			Topic:    topic,
			Speaker:  speaker,
		}
		sp.SetRenderOpts(opts) // <-- Explicitly set after creation

		proposals = append(proposals, sp)
	}
}

func ReviewProposal(title, comments, reviewer string, score int) {
    title, _ = url.QueryUnescape(title)
    comments, _ = url.QueryUnescape(comments)
    reviewer, _ = url.QueryUnescape(reviewer)
	api.AssertAtLeastRole("reviewer", std.OriginCaller())
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
    title, _ = url.QueryUnescape(title)
    approver, _ = url.QueryUnescape(approver)

	api.AssertAtLeastRole("organizer", std.OriginCaller())
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
    approver, _ = url.QueryUnescape(approver)
    if len(titles) == 0 {
        return
    }

    for i, title := range titles {
        titles[i], _ = url.QueryUnescape(title)
    }
	api.AssertAtLeastRole("organizer", std.OriginCaller())
	for _, title := range titles {
		ApproveProposal(title, approver)
	}
}

func EditProposal(title, key, edit string) error {
    title, _ = url.QueryUnescape(title)
    key, _ = url.QueryUnescape(key)
    edit, _ = url.QueryUnescape(edit)

	for _, p := range proposals {
		if p.GetTitle() != title {
			continue
		}

		if !(api.HasRole("proposer", std.OriginCaller()) && std.OriginCaller().String() == p.GetOwner()) {
			return ufmt.Errorf("unauthorized: %q may not edit %q", std.OriginCaller(), p.GetTitle())
		}

		switch strings.ToLower(key) {
		case "title":
			p.SetTitle(edit)

		case "abstract":
			p.SetAbstract(edit)

		case "speaker":
			p.SetSpeaker(edit)

		case "topic":
			if topic, ok := EventTopics[edit]; ok {
				p.SetTopic(topic)
			} else {
				return ufmt.Errorf("unknown topic %q", topic)
			}

		case "comments":
			if rp, ok := p.(*proposal.ReviewedProposal); ok {
				rp.SetComments(edit)
			} else {
				return ufmt.Errorf("proposal %q is not in Reviewed state", title)
			}

		case "score":
			if rp, ok := p.(*proposal.ReviewedProposal); ok {
				i, err := strconv.Atoi(edit)
				if err != nil {
					return ufmt.Errorf("invalid score %q: %w", edit, err)
				}
				rp.SetScore(i)
			} else {
				return ufmt.Errorf("proposal %q is not in Reviewed state", title)
			}

		case "reviewer":
			if rp, ok := p.(*proposal.ReviewedProposal); ok {
				rp.SetReviewer(edit)
			} else {
				return ufmt.Errorf("proposal %q is not in Reviewed state", title)
			}

		case "approvedby":
			if ap, ok := p.(*proposal.ApprovedProposal); ok {
				ap.SetApprovedBy(edit)
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
	var approved []proposal.Proposal
	for _, p := range proposals {
		if p.GetState() == proposal.Approved {
			base := &proposal.SubmittedProposal{
				Title:    p.GetTitle(),
				Abstract: p.GetAbstract(),
				Topic:    p.GetTopic(),
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

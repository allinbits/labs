package proposals

import (
	"strings"

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
		Title:    "Ken Thompson interviewed by Brian Kernighan",
		Abstract: "In the 1960s-1970s, Ken Thompson co-invented the UNIX operating system along with Dennis Ritchie at Bell Labs. He also worked on the language B, the operating system Plan 9, and the language Go. He and Ritchie won the Turing Award. He now works at Google. He’ll be interviewed by Brian Kernighan of “K&amp;R” fame.",
		Format:   ValidFormats["Fireside Chat"],
		Speaker:  "Ken Thompson and Brian Kernighan",
	},
	&proposal.ReviewedProposal{
		SubmittedProposal: proposal.SubmittedProposal{
			Title:    "Pseudorandomness of Sato-Tate Distributions for Elliptic Curves",
			Abstract: "In this paper we propose conjectures that assert that, the sequence of Frobeniusangles of a given elliptic curve overQwithout complex multiplication is pseudorandom, inother words that the Frobenius angles arestatistically independentlydistributed with respectto the Sato-Tate measure. Numerical evidence is presented to support the conjectures.",
			Format:   ValidFormats["Lecture"],
			Speaker:  "Chung Pang Mok and Huimin Zheng",
		},
		Comments: "The crypotgraphy could be useful w/r/t the blockchain 🤔",
		Score:    5,
		Reviewer: "Alice Johnson",
	},
	/*
		 	&proposal.ReviewedProposal{
				SubmittedProposal: proposal.SubmittedProposal{
					Title:    "Fast and Layout-Oblivious Tensor-Matrix Multiplication with BLAS",
					Abstract: "The tensor-matrix multiplication is a basic tensor operation required by various tensor methods such as the ALS and the HOSVD. This paper presents flexible high-performance algorithms that compute the tensor-matrix product according to the Loops-over-GEMM (LoG) approach. Our algorithms can process dense tensors with any linear tensor layout, arbitrary tensor order and dimensions all of which can be runtime variable. We discuss different tensor slicing methods with parallelization strategies and propose six algorithm versions that call BLAS with subtensors or tensor slices. Their performance is quantified on a set of tensors with various shapes and tensor orders. Our best performing version attains a median performance of 1.37 double precision Tflops on an Intel Xeon Gold 6248R processor using Intel’s MKL. We show that the tensor layout does not affect the performance significantly. Our fastest implementation is on average at least 14.05% and up to 3.79x faster than other state-of-the-art approaches and actively developed libraries like Libtorch and Eigen.",
					Format:   ValidFormats["Lecture"],
					Speaker:  "Cem Savaş Başsoy",
				},
				Comments: "Cool but not relevant to this event.",
				Score:    4,
				Reviewer: "Alice Johnson",
			},
	*/
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

// --- API-Like Endpoints ---

// Submit a new proposal
func SubmitProposal(title, abstract, formatName, speaker string) {
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

// Review an existing proposal (by title)
func ReviewProposal(title, comments, reviewer string, score int) {
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

// Approve a reviewed proposal (by title)
func ApproveProposal(title, approver string) {
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

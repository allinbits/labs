package gnoplan

import (
	"gno.land/p/demo/ufmt"
)

// Proposal ID for the current poll round.
// Could be passed via argument or predefined per deployment.
var proposalID string = "p002"

// Main entry point to submit a rubric score.
func score(alignment int, impact int, originality int, decentralization int, ecosystem int, note string,
) {
	if !validScore(alignment) ||
		!validScore(impact) ||
		!validScore(originality) ||
		!validScore(decentralization) ||
		!validScore(ecosystem) {
		panic("invalid score (must be 1–5)")
	}

	_ = ufmt.Sprintf

	// Event("rubric:score", fmt.Sprintf(
	//
	//	"proposal=%s alignment=%d impact=%d originality=%d decentralization=%d ecosystem=%d note=%q by=%s",
	//	proposalID, alignment, impact, originality, decentralization, ecosystem, note, Caller(),
	//
	// ))
}

// Optional helper to enforce range
func validScore(score int) bool {
	return score >= 1 && score <= 5
}

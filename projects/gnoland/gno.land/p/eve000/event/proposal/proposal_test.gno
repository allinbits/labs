package proposal

import (
	"strings"
	"testing"
)

func TestFormatTypeString(t *testing.T) {
	solo := FormatType{
		Name:        "Talk",
		Description: "Single speaker format",
		Duration:    30,
		MinSpeakers: 1,
		MaxSpeakers: 1,
	}

	panel := FormatType{
		Name:        "Panel",
		Description: "Multi-speaker discussion",
		Duration:    60,
		MinSpeakers: 2,
		MaxSpeakers: 4,
	}

	expectedSolo := "### **Talk | 30** Minutes **| 1** Speaker\n\nSingle speaker format\n\n"
	expectedPanel := "### **Panel | 60** Minutes **| 2-4** Speakers\n\nMulti-speaker discussion\n\n"

	if solo.String() != expectedSolo {
		t.Fatalf("FormatType solo string mismatch:\nExpected:\n%s\nGot:\n%s", expectedSolo, solo.String())
	}

	if panel.String() != expectedPanel {
		t.Fatalf("FormatType panel string mismatch:\nExpected:\n%s\nGot:\n%s", expectedPanel, panel.String())
	}
}

func TestStateString(t *testing.T) {
	tests := map[State]string{
		Submitted: "Submitted",
		Reviewed:  "Reviewed",
		Approved:  "Approved",
		State(99): "Unknown",
	}

	for state, expected := range tests {
		if state.String() != expected {
			t.Errorf("State %d: expected %q, got %q", state, expected, state.String())
		}
	}
}

func TestSubmittedProposal_String(t *testing.T) {
	format := FormatType{Name: "Talk"}
	sp := SubmittedProposal{
		Title:       "Session A",
		Description: "Concurrency in Go",
		Format:      format,
		Speaker:     "Alice",
	}

	out := sp.String()
	if !containsAll(out, []string{
		"### Session A",
		"Speaker - **Alice**",
		"Format - **Talk**",
		"Concurrency in Go",
		"**State:** Submitted",
	}) {
		t.Fatalf("SubmittedProposal.String() missing expected fields:\n%s", out)
	}
}

func TestReviewedProposal_String(t *testing.T) {
	sp := SubmittedProposal{
		Title:       "Session B",
		Description: "Category Theory",
		Format:      FormatType{Name: "Lecture"},
		Speaker:     "Bob",
	}
	rp := ReviewProposal(sp, "Great depth", 9, "Dr. Reviewer")

	out := rp.String()
	if !containsAll(out, []string{
		"### Session B",
		"Speaker - **Bob**",
		"Format - **Lecture**",
		"**Comments:** Great depth",
		"**Score:** 9",
		"**Reviewed by:** Dr. Reviewer",
	}) {
		t.Fatalf("ReviewedProposal.String() missing expected fields:\n%s", out)
	}
}

func TestApprovedProposal_String(t *testing.T) {
	sp := SubmittedProposal{
		Title:       "Session C",
		Description: "Ethics of AI",
		Format:      FormatType{Name: "Panel"},
		Speaker:     "Charlie",
	}
	rp := ReviewProposal(sp, "Important topic", 8, "Alex")
	ap := ApproveProposal(rp, "Zelda")

	out := ap.String()
	if !containsAll(out, []string{
		"### Session C",
		"Speaker - **Charlie**",
		"**State:** Approved",
		"**Comments:** Important topic",
		"**Score:** 8",
		"**Reviewed by:** Alex",
		"**Approved by:** Zelda",
	}) {
		t.Fatalf("ApprovedProposal.String() missing expected fields:\n%s", out)
	}
}

func TestReviewProposalTransition(t *testing.T) {
	sp := SubmittedProposal{
		Title:       "Session D",
		Description: "Test Driven Dev",
		Format:      FormatType{Name: "Workshop"},
		Speaker:     "Dana",
	}
	rp := ReviewProposal(sp, "Strong proposal", 10, "Eva")

	if rp.GetState() != Reviewed {
		t.Fatalf("Expected state Reviewed, got %v", rp.GetState())
	}
	if rp.Score != 10 || rp.Comments != "Strong proposal" {
		t.Fatal("ReviewedProposal data not set correctly")
	}
}

func TestApproveProposalTransition(t *testing.T) {
	sp := SubmittedProposal{
		Title:       "Session E",
		Description: "Scaling Systems",
		Format:      FormatType{Name: "Talk"},
		Speaker:     "Sam",
	}
	rp := ReviewProposal(sp, "Scalable focus", 7, "Taylor")
	ap := ApproveProposal(rp, "Morgan")

	if ap.GetState() != Approved {
		t.Fatalf("Expected state Approved, got %v", ap.GetState())
	}
	if ap.ApprovedBy != "Morgan" {
		t.Fatal("ApprovedBy not set correctly")
	}
}

func containsAll(haystack string, needles []string) bool {
	for _, needle := range needles {
		if !strings.Contains(haystack, needle) {
			return false
		}
	}
	return true
}

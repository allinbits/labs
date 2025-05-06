package transaction

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"testing"

	"github.com/allinbits/labs/projects/eventmemos_vm/lexer"
)

func TestMemosTXT(t *testing.T) {
	println("\nTestMemosTXT")
	tags := map[string]TagSet{
		"org":            &ValidElementsSet{map[string]struct{}{"btf": {}}},
		"location":       &ValidElementsSet{map[string]struct{}{"virtual": {}}},
		"dates":          &ValidDateRangeSet{"2006-01-02"},
		"min_bid_amount": &PositiveIntSet{},
		"min_capacity":   &PositiveIntSet{},
	}
	eve_memory := EveMemory{Tags: tags}

	file, err := os.Open("memos.txt")
	if err != nil {
		t.Fatalf("failed to open memos.txt: %v", err)
	}
	defer file.Close()

	var memos []string
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		memos = append(memos, scanner.Text())
	}
	if err := scanner.Err(); err != nil {
		t.Fatalf("error reading memos.txt: %v", err)
	}

	for _, line := range memos {
		lexer := lexer.LexMemosTXTLine("memo", line)
		commitment := &Commitment{
			Tx:      lexer.NextToken().Val,
			Address: lexer.NextToken().Val,
			Coins:   mustAtoi(t, lexer.NextToken().Val),
			Memo:    lexer.NextToken().Val,
		}
		eve_memory.ImportCommitment(commitment)
	}

	if len(eve_memory.Transactions) != 14 {
		t.Errorf("expected 14 transactions, got %d", len(eve_memory.Transactions))
	}

	CompileTransactions(&eve_memory)

	println("### BIDS ###")
	for _, bid := range eve_memory.Bids {
		fmt.Println(bid)
	}
	println("### PROPOSALS ###")
	for _, proposal := range eve_memory.Proposals {
		fmt.Println(proposal)
	}

	if len(eve_memory.Bids) != 5 {
		t.Errorf("expected 5 bids, got %d", len(eve_memory.Bids))
	}

	if len(eve_memory.Proposals) != 1 {
		t.Errorf("expected 1 proposals, got %d", len(eve_memory.Proposals))
	}
}

func TestBid(t *testing.T) {
	println("\nTestBid")
	tags := map[string]TagSet{
		"org":      &ValidElementsSet{map[string]struct{}{"btf": {}}},
		"location": &ValidElementsSet{map[string]struct{}{"virtual": {}}},
		"dates":    &ValidDateRangeSet{"2006-01-02"},
	}
	eve_memory := EveMemory{Tags: tags}

	acct := "atone10wnrpng2mk4qnex23mr5ekm6vzv8xmj3h7lw2m"
	eve_memory.ImportCommitment(&Commitment{"0x00000001", acct, 100, `eve.Bid("org:btf", "location:virtual", "dates:2025-10-01...2025-12-02")`})
	eve_memory.ImportCommitment(&Commitment{"0x00000002", acct, 10, `eve.UpdateBid("0x00000001", "org:btf")`})

	if len(eve_memory.Transactions) != 2 {
		t.Errorf("expected 2 transactions, got %d", len(eve_memory.Transactions))
	}

	CompileTransactions(&eve_memory)

	if len(eve_memory.Bids) != 1 {
		t.Errorf("expected 1 bid, got %d", len(eve_memory.Bids))
	}

	// Check that the bid's Stake has been updated to 110 (100 + 10)
	if eve_memory.Bids[0].Coins != 110 {
		t.Errorf("expected bid stake to be 110, got %d", eve_memory.Bids[0].Coins)
	}

	// Check that the bid's Intents contains the expected "org" value "btf"
	if intent, ok := eve_memory.Bids[0].Intents["org"]; !ok || intent != "btf" {
		t.Errorf("expected bid intent for org to be 'btf', got %q", intent)
	}
	fmt.Println(eve_memory.Bids)
}

func TestProposal(t *testing.T) {
	println("\nTestProposal")
	acct := "atone10wnrpng2mk4qnex23mr5ekm6vzv8xmj3h7lw2m"
	acct2 := "atone0u3r0c49mpfc7xx046mvanr3k2k4fef8w3vj6v6"
	tags := map[string]TagSet{
		"org":            &ValidElementsSet{map[string]struct{}{"btf": {}}},
		"location":       &ValidElementsSet{map[string]struct{}{"virtual": {}}},
		"dates":          &ValidDateRangeSet{"2006-01-02"},
		"min_bid_amount": &PositiveIntSet{},
		"min_capacity":   &PositiveIntSet{},
	}
	eve_memory := EveMemory{Tags: tags}

	eve_memory.ImportCommitment(&Commitment{"0x00000001", acct, 100, `eve.Bid("org:btf", "location:virtual", "dates:2025-10-01...2025-12-02")`})
	eve_memory.ImportCommitment(&Commitment{"0x00000002", acct, 10, `eve.UpdateBid("0x00000001", "org:btf", "location:virtual", "dates:2025-10-01...2025-12-03")`})
	eve_memory.ImportCommitment(&Commitment{"0x00000003", acct2, 0, `eve.Proposal("min_bid_amount:2", "min_capacity:5", "org:btf", "location:virtual", "dates:2025-10-01...2025-12-03")`})
	eve_memory.ImportCommitment(&Commitment{"0x00000004", acct2, 0, `eve.UpdateProposal("0x00000003", "dates:2025-10-11...2025-12-13")`})

	CompileTransactions(&eve_memory)

	if len(eve_memory.Transactions) != 4 {
		t.Errorf("expected 4 transactions, got %d", len(eve_memory.Transactions))
	}

	if len(eve_memory.Bids) != 1 {
		t.Errorf("expected 1 bid, got %d", len(eve_memory.Bids))
	}

	// Check that the bid's Stake has been updated to 110 (100 + 10)
	if eve_memory.Bids[0].Coins != 110 {
		t.Errorf("expected bid stake to be 110, got %d", eve_memory.Bids[0].Coins)
	}

	// Check that the bid's Intents contains the expected "org" value "btf"
	if intent, ok := eve_memory.Bids[0].Intents["org"]; !ok || intent != "btf" {
		t.Errorf("expected bid intent for org to be 'btf', got %q", intent)
	}

	if len(eve_memory.Proposals) != 1 {
		t.Errorf("expected 1 proposal, got %d", len(eve_memory.Proposals))
	}

	// Check that the Proposals Stake has been updated to 0 (0 + 0)
	if eve_memory.Proposals[0].Coins != 0 {
		t.Errorf("expected bid stake to be 0, got %d", eve_memory.Proposals[0].Coins)
	}

	// Check that the proposals's Constraints contains the expected "dates" value "2025-10-11...2025-12-13"
	if constraint, ok := eve_memory.Proposals[0].Constraints["dates"]; !ok || constraint != "2025-10-11...2025-12-13" {
		t.Errorf("expected bid intent for org to be 'btf', got %q", constraint)
	}
	fmt.Println(eve_memory.Bids)
	fmt.Println(eve_memory.Proposals)
}

func TestPledge(t *testing.T) {
	acct := "atone10wnrpng2mk4qnex23mr5ekm6vzv8xmj3h7lw2m"
	tags := map[string]TagSet{
		"org":      &ValidElementsSet{map[string]struct{}{"btf": {}}},
		"location": &ValidElementsSet{map[string]struct{}{"virtual": {}}},
		"dates":    &ValidDateRangeSet{"2006-01-02"},
	}
	eve_memory := EveMemory{Tags: tags}

	eve_memory.ImportCommitment(&Commitment{"0x00000001", acct, 100, `pledge.Create("msg: pledge to BTF")`})
	eve_memory.ImportCommitment(&Commitment{"0x00000002", acct, 10, `pledge.Update("0x00000001")`})

	if len(eve_memory.Transactions) != 2 {
		t.Errorf("expected 2 transactions, got %d", len(eve_memory.Transactions))
	}
	// assert eve_memory.pledges[0].stake == 110
}

func mustAtoi(t *testing.T, s string) int {
	i, err := strconv.Atoi(s)
	if err != nil {
		t.Fatalf("failed to convert %q to int: %v", s, err)
	}
	return i
}

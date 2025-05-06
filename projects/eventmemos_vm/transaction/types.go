package transaction

import (
	"fmt"
	"strconv"
	"strings"
	"time"
)

type EveMemory struct {
	Tags           map[string]TagSet
	Transactions   []*Commitment
	EntryProcessor map[string]map[string]EntryContext
	Bids           []*Bid
	Proposals      []*Proposal
	//Pledges []*Pledge
}

func (m *EveMemory) ImportCommitment(commitment *Commitment) {
	m.Transactions = append(m.Transactions, commitment)
}

// TagSet represents a set that will check if it contains a given value.
type TagSet interface {
	Contains(value string) bool
}

type Commitment struct {
	Tx      string // First 8 hex digits from AtomOne transaction hash
	Address string // address from transaction
	Coins   int    // amount in PHOTON from transaction
	Memo    string // memo field from transaction
}

type Entry interface {
	isEntry()
}

type EntryContext struct {
	LastTx string
	Entry  Entry
}

type Bid struct {
	Address string
	ID      string
	Coins   int
	Intents map[string]string
	// For example intents:
	// "location": "San Francisco"
	// "org": "btf"
	// "dates": "10-01-2025...10-10-2025"
}

type Proposal struct {
	Organizer   string
	ID          string
	Coins       int
	Constraints map[string]string
	// For example constraints:
	// "min_bid_amount": 2
	// "min_capactiy": 5
	// "location": "virtual"
	// "org": "btf"
	// "dates": "10-02-2025"
}

type Pledge struct {
	Address string
	ID      string
	Coins   int
	Intents map[string]string
	// Example: intents:
	// "pinned": "0x123aaaa0"
}

func (b *Bid) isEntry()      {}
func (p *Proposal) isEntry() {}
func (p *Pledge) isEntry()   {}

type ValidElementsSet struct {
	valid_elements map[string]struct{}
}

func (s *ValidElementsSet) Contains(element string) bool {
	_, exists := s.valid_elements[element]
	return exists
}

type ValidDateRangeSet struct {
	layout string
}

func (s *ValidDateRangeSet) Contains(date string) bool {
	parts := strings.Split(date, "...")
	if len(parts) != 2 {
		return false
	}
	start_date, err1 := time.Parse(s.layout, parts[0])
	end_date, err2 := time.Parse(s.layout, parts[1])
	if err1 != nil || err2 != nil {
		return false
	}
	return start_date.Before(end_date) || start_date.Equal(end_date)
}

type PositiveIntSet struct{}

func (s *PositiveIntSet) Contains(value string) bool {
	i, err := strconv.Atoi(value)
	if err != nil {
		return false
	}
	return i > 0
}

func (b *Bid) String() string {
	return fmt.Sprintf("Bid{ID: %s, Address: %s, Coins: %d, Intents: %v}", b.ID, b.Address, b.Coins, b.Intents)
}

func (p *Proposal) String() string {
	return fmt.Sprintf("Proposal{ID: %s, Organizer: %s, Coins: %d, Constraints: %v}", p.ID, p.Organizer, p.Coins, p.Constraints)
}

package transaction

import "strconv"

func IsValid(proposal *Proposal, bids []*Bid) bool {
	for _, bid := range bids {
		if !bid.Satisfies(proposal) {
			return false
		}
	}
	min_capacity, _ := strconv.Atoi(proposal.Constraints["min_capacity"])
	if proposal.HasMaxAttendence() {
		max_capacity, _ := strconv.Atoi(proposal.Constraints["max_capacity"])
		if len(bids) > max_capacity || len(bids) < min_capacity {
			return false
		}
	}
	return len(bids) == min_capacity
}

func (b *Bid) Satisfies(proposal *Proposal) bool {
	panic("Not Implemented")
}

func (p *Proposal) HasMaxAttendence() bool {
	panic("Not Implemented")
}

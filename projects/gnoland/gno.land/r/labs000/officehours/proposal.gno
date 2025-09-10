package officehours

type proposalCache struct {
	lastProposals []string
}

var (
	proposal     = proposalCache{}
	maxProposals = 20
)

func (p proposalCache) Add(cid string, path string) {
	p.lastProposals = append(p.lastProposals, path+"&cid="+cid)
	if len(p.lastProposals) > maxProposals {
		p.lastProposals = p.lastProposals[1:]
	}
}

func (p proposalCache) List() string {
	var result string
	for i := len(p.lastProposals) - 1; i >= 0; i-- {
		result += p.lastProposals[i] + "\n"
	}
	return result
}

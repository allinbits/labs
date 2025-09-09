package officehours

type Proposal struct {
    lastProposals []string
}
var proposal = Proposal{}

func (p Proposal)Add(cid string, path string) {
    p.lastProposals = append(p.lastProposals, path + "&cid=" + cid)
    if len(p.lastProposals) > 20 {
        p.lastProposals = p.lastProposals[1:]
    }
}

func (p Proposal)List() string {
    var result string
    for i := len(p.lastProposals) - 1; i >= 0; i-- {
        result += p.lastProposals[i] + "\n"
    }
    return result
}


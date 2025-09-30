package home

import (
	"gno.land/r/labs000/logoverse"
	"gno.land/r/labs000/officehours"
)

func Render(_ string) string {
	return `# Welcome to the All in Bits LabsNet!

Welcome to the experimental Labs Net testnet - a playground for innovation and testing on the Gno blockchain.

## What is Labs Net?

Labsnet is an ephemeral testnet run by the All In Bits Labs team is designed flexible environment for sharing our work with the public.

Labs Net is our dedicated testnet environment:

- **Experiment** with smart contracts and realms
- **Test** new features and implementations
- **Deploy** and interact with Gno packages
- **Innovate** without mainnet constraints

` + officehours.Render("?embed=banner") + `

## LogoGraphs

[` + logoverse.Render("?glyph=Logoverse&embed=img") + `Logoverse Index](/r/labs000/logoverse)


## Project Menu

### gno.land/p
- [eve000/event/](/p/eve000/event/) - eve000 provides a gnolang component library for events
- [metamodel000](/p/metamodel000/) - metamodel000 provides petri net metamodels for gnolang
- [rss000/feed](/p/rss000/feed/) - RSS service

### gno.land/r
- [buidlthefuture000](/r/buidlthefuture000) - BUIDL THE FUTURE project landing page
- [buidlthefuture000/events/](/r/buidlthefuture000/events) - BTF Events Index
- [cdn000](/r/cdn000) - CDN for static files (proxy for jsDelivr e.g. /gh/BUIDLTHEFUTURE/events@main/static/)
- [frames000](/r/frames000) - Frames for Gno - build js widgets as gnomark HtmlElements
- [labs000/home](/r/labs000/home) - LabsNet home page (this page)
- [linker000](/r/linker000) - Gno Linker - a tool for linking Gno Addresses to External Resources
- [logoverse](/r/labs000/logoverse) - Logoverse - a decentralized knowledge graph of LogoGraphs
- [metamodel000](/r/metamodel000) - Library of metamodels for gnolang (WIP)
- [officehours](/r/labs000/officehours) - Schedule and post topics for office hours
- [stackdump000/grc000](/r/stackdump000/grc000) - Experimental GRC000 Petri Net Model
- [stackdump000/home](/r/stackdump000/home) - Stackdump home page
`
}

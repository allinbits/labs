package events

import (
	"gno.land/p/eve000/event/component"
)

func addBlock(key, body string) {
	register(key, func(_ string) string {
		return body
	})
	displayPaths = append(displayPaths, key)
}

func init() {
	addBlock("Buidl the Future", intro)
	addBlock("Upcoming", latestEvent)
	addBlock("Contribute", contact)
	addBlock("Topics", topics)
}

var latestEvent = `
Next event: [gno.land Launch Event](/r/buidlthefuture000/events/gnolandlaunch).
`

var intro = `

Join a growing community of builders, thinkers, and aligned communities
focused on the original purpose of blockchain:

#### **Censorship-resistance, Sovereignty, & Decentralized Coordination.**

![BTF events logo](https://cdn.jsdelivr.net/gh/BUIDLTHEFUTURE/events@main/static/img/logo.png)

This event series tackles urgent, real-world challenges—privacy, security, identity, governance, information discovery, and AI—by applying decentralized technologies.

Our goal is to expose how blockchain enables exit from legacy systems of control, while also charting practical paths toward autonomy and resilience.

#### Let’s build the future—together.`

var contact = `
Review the topics below to see what resonates with you. We welcome all builders, thinkers, and communities who share our vision.

If you wish to get involved, have ideas, or want to help organize future events, please create a github issue.` + component.Button("Add GitHub Issue", "https://github.com/BUIDLTHEFUTURE/events/issues/new") + `
`

var topics = `

#### 🔐 1. Privacy, Security & Identity
Explore how decentralized systems help us communicate, authenticate, and defend against manipulation:

* Encrypted communication & censorship-resistant messaging

* Self-sovereign identity (DID), wallet-based login

* Bridging real and digital identity

* UX/security tradeoffs in decentralized tools

* Coping with deepfakes, AI-driven identity fraud, and misinformation

#### 📰 2. Information, Media & Social Infrastructure
Create new platforms to replace centralized knowledge and discourse systems:

* A decentralized Wikipedia, Twitter, Reddit, etc.

* Balancing moderation with censorship resistance

* Tools for information discovery & content truth assessment

* Streaming without reliance on Big Tech

#### 🧑‍⚖️ 3. Governance & Regulation
Rethinking governance from local town halls to digital DAOs:

* Innovations in collective decision-making

* Open dialogue between builders and regulators

* Navigating legal clarity and responsible Web3 design

#### 🧰 4. Infrastructure, Tools & Developer UX
Foundational technologies powering decentralized experiences:

* Wallet UX: hardware, software, extensions

* Transitioning from Web2 to Web3

* Onboarding strategies and tooling

* Spotlight on the Cosmos ecosystem

#### 🌐 5. Gno.land & The Logoverse
Highlighting Gno.land’s role as the first Logoverse—a language-based OS for decentralized coordination:

* Gno.land as a knowledge and coordination hub

* Persistent contracts, composable multi-user logic

* Tools for building powerful, expressive dApps

* Human-machine interaction reimagined

#### 🤖 6. The Intersection of AI & Web3
How Gno.land can power transparent, auditable AI:

* AI agents in the Logoverse

* Tools for collective intelligence and community-curated knowledge

* Using AI to accelerate and verify dApp development

#### 🏡 7. Secure Home Computing
Redefining the PC as a sovereign node in decentralized networks:

* Secure-by-design local infrastructure

* Owning and controlling your personal data
`

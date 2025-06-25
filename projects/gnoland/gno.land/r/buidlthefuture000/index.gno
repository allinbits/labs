package events

func addBlock(key, body string) {
	register(key, func(_ string) string {
		return body
	})
	displayPaths = append(displayPaths, key)
}

func init() {
	addBlock("Buidl the Future", intro)
}

var intro = `
This realm contains the BUIDL THE FUTURE (BTF) project.
* 💬 [Discord](https://discord.gg/YFtMjWwUN7) Join us on discord.
* 📅 [/r/buidlthefuture000/events](/r/buidlthefuture000/events) - on-chain events hosted by BTF
* 🧩 [/p/eve000/event](/p/eve000) - eve000 provides a gnolang component library for events
* 🛠️ [GitHub](https://github.com/BUIDLTHEFUTURE/events) - report issues & contribute to the project
* 📦 [CDN files](https://cdn.jsdelivr.net/gh/BUIDLTHEFUTURE/events@main/static/) - static file hosting via jsDelivr
* 🧪 [AIBLabs](https://github.com/allinbits/labs) - review AIB labs projects still in incubation
`

package s1e1

import (
    "time"
	"gno.land/p/eve000/event"
	eve "gno.land/p/eve000/event/component"
)

var (
    publicationDate = time.Now()
	defaultOpts    = map[string]any{
		"dev": map[string]any{},
		"labsnet1": map[string]any{},
	}
)

func optsWithKeyValue(key string, value any, inputOpts ...map[string]any) map[string]any {
    opts := defaultOpts
    if len(inputOpts) > 0 {
        opts = inputOpts[0]
    }
    for k, v := range defaultOpts {
        opts[k] = v
        opts[k].(map[string]any)[key] = value
    }
    return opts
}

func withoutTitle(opts ...map[string]any) map[string]any {
    return optsWithKeyValue("SessionsTitle", "", opts...)
}

func withSpeaker(opts ...map[string]any) map[string]any {
    return optsWithKeyValue("Speaker", struct{}{}, opts...)
}

func contentBlock(content string) eve.Content {
	return eve.Content{Published: true, Markdown: content}
}

var nav = contentBlock(`
- page | [index](?) | [speakers](?p=speakers)
`)

var session = contentBlock(`
- What is the Logoverse?
- Why Petri-nets?
- How do Petri-nets work?
- Examples of Petri-nets
`)

func episode(opts map[string]any) *event.Event {
	evt := &event.Event{
		Name:           "Intro To Petri-nets",
		Description:    "Introducing the Logoverse",
		Status:         eve.EventScheduled, // show the date
		StartDate:      publicationDate,
		EndDate:        publicationDate,
	}
	evt.Sessions = []*eve.Session{
		{
		    Title:       "What is the Logoverse?",
			Description: session.Render(),
			Speaker: &eve.Speaker{
				Name:        "Matt York",
				Address:     "g1e8vw6gh284q7ggzqs8ne6r8j9aqhnmvl6rzzmz",
				Affiliation: "[allinbits.com](https://allinbits.com)",
				Biography:   "[gh/stackdump](https://github.com/stackdump)",
			},
		},
	}
	evt.SetRenderOpts(opts)
	return evt
}

func Render(path string) string {
	q := eve.ParseQuery(path)
	var content []eve.Content
	var evt *event.Event
	page := q.Get("p")
	switch page {
	case "speakers":
		content = []eve.Content{nav}
		evt = episode(withSpeaker())
	default:
		content = []eve.Content{nav}
		evt = episode(withoutTitle())
	}
	return evt.RenderPage(path, content...)
}

func Event() *eve.Flyer {
    return episode(withSpeaker()).Flyer()
}
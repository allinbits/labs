package s1e0

import (
	"gno.land/p/eve000/event"
	eve "gno.land/p/eve000/event/component"
	ohr "gno.land/r/labs000/officehours"
)

const S001E000 = "s001e000"

func init() {
	ohr.Register(Episode.Record())
}

func Render(path string) string {
	return ohr.RenderEpisode(path, Episode.Record()[S001E000])
}

type episode struct {}
/*
POV: You’re building a tiny, stateless DSL where each episode is a pure, namespaced object
all extensibility happens via composable writers — not mutable state.
*/
var Episode = episode{}

func (episode)Record() map[string]ohr.Record {
	return map[string]ohr.Record{
		S001E000: ohr.Record{
			Episode:    Episode.Event,
			Content:    ohr.Nav(`- nav | [index](?) `),
			EvtWriters: ohr.Writer(
                ohr.ApplyScheduleOptionsFromPath,
                ohr.InDraft,
                //ohr.PublishDraft,
			),
			Meta:       ohr.Keywords("tutorial", "getting started"),
		},
	}
}

func (episode)Event(opts map[string]any) *event.Event {
	return &event.Event{
		Name:        "Hello, Logoverse",
		Description: "Your first Episode!",
		Sessions: []*eve.Session{
			{
				Title:       "App.go",
				Description: "Minimum viable app.go",
				Body:        []eve.Content{ eve.Content{Published: true, Markdown: "Hello Logoverse!" }},
			},
		},
	}
}


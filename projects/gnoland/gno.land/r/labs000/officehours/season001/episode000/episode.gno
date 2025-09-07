package s1e0

import (
	"gno.land/p/eve000/event"
	eve "gno.land/p/eve000/event/component"
	ohr "gno.land/r/labs000/officehours"
)

const S001E000 = "s001e000"

func init() {
	ohr.Register(Record())
}

func Record() map[string]ohr.Record {
	return map[string]ohr.Record{
		S001E000: ohr.Record{
			Episode:    Episode,
			Content:    ohr.Nav(`- nav | [index](?) `),
			EvtWriters: ohr.Writer(ohr.ApplyScheduleOptionsFromPath),
			Meta:       ohr.Keywords("tutorial", "getting started"),
		},
	}
}

func Render(path string) string {
	return ohr.RenderEpisode(path, Record()[S001E000])
}

func Episode(opts map[string]any) *event.Event {
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


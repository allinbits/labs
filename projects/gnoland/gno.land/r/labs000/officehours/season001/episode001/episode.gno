package s1e1

import (
	"time"

	"gno.land/p/eve000/event"
	eve "gno.land/p/eve000/event/component"
	ohr "gno.land/r/labs000/officehours"
)

const S001E001        = "s001e001"
var publicationDate = time.Now()

func init() {
	ohr.Register(Record())
}

var nav = ohr.ContentBlock(`
- v0 | [index](?) | [speakers](?p=speakers)
`)

func Record() map[string]ohr.Record {
	return map[string]ohr.Record{
		S001E001: {
			Episode,
			[]*eve.Content{nav},
			[]ohr.EvtWriter{ohr.ApplyScheduleOptionsFromPath},
			[]string{"logoverse"},
		},
	}
}

func Render(path string) string {
	return ohr.RenderEpisode(path, Record()[S001E001])
}

func Episode(opts map[string]any) *event.Event {
	evt := &event.Event{
		Name:        "Intro To Petri-nets",
		Description: "Introducing the Logoverse",
		StartDate:   publicationDate,
		EndDate:     publicationDate,
	}
	evt.Sessions = append(evt.Sessions, WhatIsTheLogoverse())
	return evt
}

/* Speaker: Matt York */

func MattYork() *eve.Speaker {
	return &eve.Speaker{
		Name:        "Matt York",
		Address:     "g1e8vw6gh284q7ggzqs8ne6r8j9aqhnmvl6rzzmz",
		Affiliation: "[allinbits.com](https://allinbits.com)",
		Biography:   "[gh/stackdump](https://github.com/stackdump)\n\n" + Pflow.Render(),
	}
}

/* Session: What is the Logoverse? */

var logoverseSession = ohr.ContentBlock(`
- What is the Logoverse?
- Why Petri-nets?
- How do Petri-nets work?
- Examples of Petri-nets
`)

func WhatIsTheLogoverse() *eve.Session {
	return &eve.Session{
		Title:   "What is the Logoverse?",
		Body:    []eve.Content{*logoverseSession},
		Speaker: MattYork(),
	}
}

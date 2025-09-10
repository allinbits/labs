package s1e1

import (
	"gno.land/p/eve000/event"
	eve "gno.land/p/eve000/event/component"
	logo "gno.land/r/labs000/logoverse"
	ohr "gno.land/r/labs000/officehours"
)

const S001E001 = "s001e001"

func init() {
	ohr.Register(Episode.Record())
}

func Render(path string) string {
	return path
}

type episode struct{}

var Episode = episode{}

func (episode) Record() map[string]ohr.Record {
	return map[string]ohr.Record{
		S001E001: {
			Episode.Event,
			ohr.Nav("- [index](?) | [speakers](?p=speakers)"),
			ohr.Writer(ohr.ApplyScheduleOptionsFromPath),
			ohr.Keywords("logoverse"),
		},
	}
}

func (episode) Event(opts map[string]any) *event.Event {
	evt := &event.Event{
		Name:        "Intro To Petri-nets",
		Description: "Introducing the Logoverse",
	}
	evt.Sessions = append(evt.Sessions, Episode.WhatIsTheLogoverse())
	return evt
}

func (episode) WhatIsTheLogoverse() *eve.Session {
	return &eve.Session{
		Title:   "What is the Logoverse?",
		Body:    []eve.Content{*logoverseSession},
		Speaker: logo.Pflow.Author(),
	}
}

var logoverseSession = ohr.ContentBlock(`
- What is the Logoverse?
- Why Petri-nets?
- How do Petri-nets work?
- Examples of Petri-nets
`)

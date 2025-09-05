package s1e1

import (
    "time"
	"gno.land/p/eve000/event"
	ohr "gno.land/r/labs000/officehours"
	eve "gno.land/p/eve000/event/component"
)

var (
    publicationDate = time.Now()
)

var nav = ohr.ContentBlock(`
- page | [index](?) | [speakers](?p=speakers)
`)

var session = ohr.ContentBlock(`
- What is the Logoverse?
- Why Petri-nets?
- How do Petri-nets work?
- Examples of Petri-nets
`)

func episode(opts map[string]any) *event.Event {
	evt := &event.Event{
		Name:           "Intro To Petri-nets",
		Description:    "Introducing the Logoverse",
		StartDate:      publicationDate,
		EndDate:        publicationDate,
	}
	evt.Sessions = []*eve.Session{
		{
		    Title:       "What is the Logoverse?",
			Body:      []eve.Content{session},
			Speaker: &eve.Speaker{
				Name:        "Matt York",
				Address:     "g1e8vw6gh284q7ggzqs8ne6r8j9aqhnmvl6rzzmz",
				Affiliation: "[allinbits.com](https://allinbits.com)",
				Biography:   "[gh/stackdump](https://github.com/stackdump)",
			},
		},
	}
	if d, ok := opts["startDate"]; ok {
        evt.StartDate = d.(time.Time)
        evt.Sessions[0].StartTime = d.(time.Time)
    }
	if d, ok := opts["endDate"]; ok {
        evt.EndDate = d.(time.Time)
        evt.Sessions[0].EndTime = d.(time.Time)
    }
    if status, ok := opts["status"]; ok {
        evt.Status = eve.Status(status.(string))
    }
	evt.SetRenderOpts(opts)
	return evt
}


func Render(path string) string {
    return ohr.RenderEpisode(path, episode, []eve.Content{nav})
}

func RenderCalendar(path string) string {
	evt := episode(ohr.WithSpeaker(ohr.GetOpts(path)))
	return evt.Render(path, eve.IcsCalendarFile)
}

func Event(path string) *eve.Flyer {
    evt := episode(ohr.WithSpeaker(ohr.GetOpts(path)))
    return evt.Flyer()
}
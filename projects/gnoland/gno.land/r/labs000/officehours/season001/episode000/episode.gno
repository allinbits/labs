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
	return Episode.Record()[S001E000].Render(path)
}

type episode struct {}
var Episode = episode{}

func (episode) Record() map[string]ohr.Record {
	return map[string]ohr.Record{
		S001E000: ohr.Record{
			Episode:    Episode.Event,
			Content:    ohr.Nav("- " + S001E000 + " | [index](?) "),
			EvtWriters: ohr.Writer(
                ohr.ApplyScheduleOptionsFromPath,
                ohr.InDraft,
                //ohr.PublishDraft,
			),
			Meta:       ohr.Keywords("tutorial", "getting-started"),
		},
	}
}

func (episode) Event(opts map[string]any) *event.Event {
	return &event.Event{
		Name:        "Hello, Logoverse",
		Description: "Hello Logoverse!",
		Sessions: []*eve.Session{
			{
				Title:       "episode.gno",
				Description: "Minimum viable episode.go",
				Body:        []eve.Content{*povDescription, eve.Content{
				    Published: true,
                    Callback: func(_ string) string {
                        return proposalForm(opts)
                     },
				}},
			},
		},
	}
}

func toString(v any) string {
    if v == nil {
        return ""
    }
    if ts, ok := v.(interface{ Format(string) string }); ok {
        return ts.Format("2006-01-02T15:04:05Z")
    }
    return v.(string)
}


var povDescription = ohr.ContentBlock(`
POV: You’re building a tiny, stateless DSL where each episode is a pure, namespaced object
all extensibility happens via composable writers — not mutable state.
`)

func proposalForm(opts map[string]any) string {
return `
<gno-columns>

<gno-form>
    <gno-input name="status" type="checkbox" checked="true" value="EventScheduled" description="Fill out form to schedule a session." />
    <gno-input name="startDate" type="checkbox" checked="true" value="`+ toString(opts["startDate"]) + `" description="StartDate" />
    <gno-input name="endDate" type="checkbox" checked="true" value="`+ toString(opts["endDate"]) + `" description="EndDate" />
    <gno-textarea name="description"  placeholder="` + toString(opts["description"]) + `"  description="Propose a session topic"/>
</gno-form>

|||

</gno-columns>
`
}
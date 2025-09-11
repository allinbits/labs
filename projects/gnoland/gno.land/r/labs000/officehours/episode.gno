package officehours

import (
	eve "gno.land/p/eve000/event/component"
)

const S000E000 = "s000e000"

func init() {
	Register(ProposedEpisode.Record())
}

type Episode struct {}
var ProposedEpisode = Episode{}

func (Episode) Record() map[string]Record {
	return map[string]Record{
		S000E000: Record{
			Episode: ProposedEpisode.Event,
			EvtWriters: Writer(
				ApplyScheduleOptionsFromPath,
				InDraft,
			),
			Meta: Keywords("tutorial", "getting-started"),
		},
	}
}

func (Episode) Event(opts map[string]any) *eve.Flyer {
	return &eve.Flyer{
		Name: "OfficeHours Proposal: " + S000E000,
		Sessions: []*eve.Session{
			{
				Description: "Use this form to submit a proposal for an office hours session. Today's date == 'Next Available' ",
				Body: []eve.Content{
					{
						Published: true,
						Callback: func(_ string) string {
							return proposalForm(opts)
						},
					},
				},
			},
		},
	}
}

func toString(v any, max ...int) string {
	if v == nil {
		return ""
	}
	if ts, ok := v.(interface{ Format(string) string }); ok {
		return ts.Format("2006-01-02T15:04:05Z")
	}

	if max != nil && len(max) > 0 {
		s := v.(string)
		if len(s) > max[0] {
			return s[:max[0]] + "..."
		}
		return s
	}
	return v.(string)
}

// REVIEW: if there is a CID set - don't show this form... it's a 'closed object'

func proposalForm(opts map[string]any) string {
	return `
<gno-columns>

<gno-form>
    <gno-input name="status" type="checkbox" checked="true" value="EventScheduled" description="Fill out form to schedule a session." />
    <gno-input name="startDate" type="text" description="StartDate" />
    <gno-input name="setStartDate" type="checkbox" checked="true" value="` + toString(opts["startDate"]) + `" placeholder="selected start"/>
    <gno-input name="endDate" type="text" description="EndDate" />
    <gno-input name="setEndDate" type="checkbox" checked="true" value="` + toString(opts["endDate"]) + `" placeholder="selected end"/>
    <gno-textarea name="description"  placeholder="` + toString(opts["description"], 500) + `"  description="Propose a session topic in 1-2 sentences. (500 chars max)"/>
    <gno-input name=setDescription type="checkbox" checked="true" value="` + toString(opts["description"], 500) + `" placeholder="proposed description"/>
</gno-form>

|||

</gno-columns>
`
}

package metamodel

import (
	mm "gno.land/p/metamodel000"
)

var folderLayout = `

This is the layout of an [Eve event folder](/r/buidlthefuture000/events/gnolandlaunch$source), which contains the following files:
- **acl.gno**: Access Control List for the event.
- **app.gno**: Application logic for the event.
- **event.gno**: Event data storage an.
- **public.gno**: Public interface for the event.

The relationships between these files are as follows:
- **contains**: App contains event data.
- **publishes**: Public exports methods from the app.
- **boundby**: App is bound by the rules of the ACL.
`

func init() {
	folderModel := eventFolderLayout()
	folderModel.Binding = func(_ string) string {
		return folderLayout + folderModel.ToMarkdown()
	}
	register("EventFolderLayout", folderModel)
}

// eve model shows the layout of the event folder
func eventFolderLayout() *mm.Model {
	places := map[string]mm.Place{
		"acl.gno":    {Offset: 0, X: 58, Y: 50},
		"app.gno":    {Offset: 1, X: 275, Y: 100},
		"event.gno":  {Offset: 2, X: 58, Y: 150},
		"public.gno": {Offset: 3, X: 469, Y: 100},
	}

	transitions := map[string]mm.Transition{
		"contains":  {X: 165, Y: 150},
		"publishes": {X: 365, Y: 100},
		"boundby":   {X: 161, Y: 50},
	}

	arrows := []mm.Arrow{
		{Source: "public.gno", Target: "publishes"},
		{Source: "publishes", Target: "app.gno"},
		{Source: "app.gno", Target: "boundby"},
		{Source: "boundby", Target: "acl.gno"},
		{Source: "app.gno", Target: "contains"},
		{Source: "contains", Target: "event.gno"},
	}

	return &mm.Model{
		Places:      places,
		Transitions: transitions,
		Arrows:      arrows,
	}
}

var eventCompositionLayout = `
This section describes the structure of an [Eve event](/p/eve000/event).

For the purposes of this model, an event is thought of as a composition of the following component types:

- **EventStatus**: Indicates the current status of the event (e.g., scheduled, cancelled).
- **EventAttendanceMode**: Specifies how the event can be attended (e.g., online, offline, mixed).
- **Speakers**: Lists the speakers participating in the event.
- **Locations**: Lists the locations where the event takes place.
- **RenderOpts**: Contains options for rendering the event.
- **Event**: Represents the event as a whole.
- **Sessions**: Contains the sessions that make up the event.
- **Flyer**: A visual component that can be rendered for the event.
- **EventDetails**: Provides details such as start date, end date, and description.
- **ContentBlock**: Allows for additional content to be injected into the flyer.

Each component is represented as a "place" in the model. "Transitions" define the relationships between these components, such as linking speakers and locations to sessions, or connecting event status and attendance mode to the event itself.

Arrows in the model illustrate how information flows between components, showing their interactions and how they together form a complete event model.

- **Inhibitor arcs** (arrows with **Inhibit: true**) are used to indicate type separation or constraints between components.


Notice that this model has a rule, an Event requires > 1 session before it can be created.

Additionally the same relation is seen between Event and Flyer, event must exist before a Flyer can be created.
`

func init() {
    eventModel := eventComposition()
    eventModel.Binding = func(_ string) string {
        return eventCompositionLayout + eventModel.ToMarkdown()
    }
    register("EventComposition", eventModel)
}

func eventComposition() *mm.Model {
	places := map[string]mm.Place{
		"EventStatus":          {Offset: 0, Initial: mm.T(1), X: 435, Y: 147},
		"EventAttendanceMode":  {Offset: 1, Initial: mm.T(1), X: 432, Y: 200},
		"Speakers":             {Offset: 2, X: 200, Y: 320},
		"Locations":            {Offset: 3, X: 200, Y: 440},
		"RenderOpts":           {Offset: 4, Initial: mm.T(1), X: 782, Y: 216},
		"Event":                {Offset: 5, X: 788, Y: 137},
		"Sessions":             {Offset: 6, X: 440, Y: 320},
		"Flyer":                {Offset: 7, X: 972, Y: 178},
		"EventDetails":         {Offset: 8, Initial: mm.T(1), X: 436, Y: 93},
		"ContentBlock":         {Offset: 9, Initial: mm.T(1), X: 974, Y: 260},
	}

	transitions := map[string]mm.Transition{
		"(Speaker)":                  {X: 320, Y: 320},
		"(Location)":                 {X: 320, Y: 440},
		"(Speaker,Location)":         {X: 320, Y: 380},
		"(Status,Attendance,Sessions)": {X: 605, Y: 138},
		"Location":                   {X: 80, Y: 440},
		"Session":                    {X: 320, Y: 240},
		"Speaker":                    {X: 80, Y: 320},
		"Flyer()":                    {X: 890, Y: 177},
		"Render()":                   {X: 1071, Y: 207},
	}

	arrows := []mm.Arrow{
		{Source: "EventStatus", Target: "(Status,Attendance,Sessions)"},
		{Source: "EventAttendanceMode", Target: "(Status,Attendance,Sessions)"},
		{Source: "Speakers", Target: "(Speaker)"},
		{Source: "Locations", Target: "(Location)"},
		{Source: "Speakers", Target: "(Speaker,Location)"},
		{Source: "Locations", Target: "(Speaker,Location)"},
		{Source: "(Speaker)", Target: "Sessions"},
		{Source: "(Location)", Target: "Sessions"},
		{Source: "(Speaker,Location)", Target: "Sessions"},
		{Source: "Speaker", Target: "Speakers"},
		{Source: "Location", Target: "Locations"},
		{Source: "(Status,Attendance,Sessions)", Target: "Event"},
		{Source: "Flyer()", Target: "Event", Inhibit: true},
		{Source: "RenderOpts", Target: "Flyer()"},
		{Source: "(Status,Attendance,Sessions)", Target: "Sessions", Inhibit: true},
		{Source: "Session", Target: "Sessions"},
		{Source: "Flyer()", Target: "Flyer"},
		{Source: "EventDetails", Target: "(Status,Attendance,Sessions)"},
		{Source: "Flyer", Target: "Render()"},
		{Source: "ContentBlock", Target: "Render()"},
	}

	return &mm.Model{
		Places:      places,
		Transitions: transitions,
		Arrows:      arrows,
	}
}
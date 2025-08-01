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

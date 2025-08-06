package gnoplan

import (
	"time"

	"gno.land/p/eve000/event"
	eve "gno.land/p/eve000/event/component"
)

var (
    publishedDate = time.Now()
    renderOpts = map[string]interface{}{
        "dev": map[string]interface{}{
            "SvgFooter":    struct{}{},
            "CalendarHost": "webcal://127.0.0.1:8080",
            "CalendarFile": "http://127.0.0.1:8080",
        },
        "labsnet1": map[string]interface{}{
            "SvgFooter":    struct{}{},
            "CalendarHost": "webcal://gnocal.aiblabs.net",
            "CalendarFile": "https://gnocal.aiblabs.net",
        },
    }
    banner = eve.Content{
        Published: true,
        Markdown: `

[Jump to Agenda View ↓](#agenda) to see the event sessions

---

| (Fig 1) See above |
|-------------------------------------------------------------------|
| ↑ Top - Heading contains the essential event details (no session data). |

***Banner*** - section is used for call-to-action, such as subscribing to the calendar or downloading the calendar file.

`}

    body = eve.Content{
        Published: true,
        Markdown: `
| (Fig 2) See Below |
|--------------------------------------------------------------------------|
| In this section, expect to find more unstructured paragraphs of markdown here.|
| For this test case: we store component docs in the body. |

***Body*** - section contains the event description and additional information.

NOTE: Markdown here may link the other parts of the flyer by anchor tags. (e.g [Agenda View](#agenda))

---
`}

    overview = eve.Content{
        Published: true,
        Markdown: `
## Overview of Components

**Overview** - Documents components used in this realm.

Use links below to view the component data in different formats.

### Files
 - [event.gno](gnopriv001$source&file=event.gno) - Contains the event definition and rendering configuration
     - Makes use of Eve Events [/p/eve000/event](/p/eve000/event)
### Structures
* ***event.Event*** -> provides read/write methods for a realm object
  * **MUST** not be exposed directly without auth
* ***event.Flyer()*** -> presents an Agenda View of the event with injectable markdown content
  * copies the event for sharing across realms
* ***component.Component*** -> interfaces to render sub-components
  * i.e. ToSvg, ToMarkdown, ToJson, ToIcs, ToJsonLD

#### Flyer
Flyer is a view presenting the event with injectable markdown content.

  - [iCalendar](?format=ics) - view iCalendar export of the event
  - [Json](?format=json) - view flyer data as json

### Event
Event is the main object that provides methods to update or replace the event.
It should not be exposed directly without authentication.

  - [JsonLD](?format=jsonld) - provides [structured data](https://developers.google.com/search/docs/appearance/structured-data/event) for search engines

#### Session
Session is scheduled block of time within the event.
  - [Markdown](?session=0) - view session
  - [Json](?session=0&format=json) - view session json

#### Speaker
Speaker is a person who is presenting at the event.
  - [Markdown](?speaker=0) - view speaker
  - [Json](?speaker=0&format=json) - view speaker json

#### Location
Location is a place where the event is happening. (In this case, it is an online event.)
  - [Markdown](?location=0) - view location
  - [Json](?location=0&format=json) - view location json
`}

    footer = eve.Content{
        Published: true,
        Markdown: `
| Fig (3) Below |
|-----------------------------------------------------------------------------|
|Rendered event agenda with sessions and speakers(optional).|

***Agenda View*** - this is the main view of the event, it shows the event details, sessions, speakers, and location (when populated & enabled by renderOpts).

***SVG Footer*** - a compactly rendered footer with all flyer details. (links back to [Event title ↑ by anchor tag](#tomorrows-just-a-day-away))

---
`}

)


// build an event for tomorrow at 1pm UTC
func tomorrowEvent() *event.Event {
    evt := &event.Event{
        Name:           "Tomorrow's just a day away",
        Status:         eve.EventScheduled,
        AttendanceMode: eve.OnlineEventAttendanceMode,
        Description:    "An event that is always tomorrow at 1pm UTC.",
        StartDate:   utc1pm(),
        EndDate:   utc2pm(),
    }
    evt.Sessions = []*eve.Session{
        {
            Title:       "Tomorrow's just a day away",
            Description: "This is a test event that is always tomorrow at 1pm UTC.",
            StartTime:   utc1pm(),
            EndTime:   utc2pm(),
            Sequence:    daysSincePublish(),
            Location:    &eve.Location{
                Name:        "Online",
            },
            Speaker: &eve.Speaker{
                Name:        "Gnobody Uknow",
                Address:     "g1e8vw6gh284q7ggzqs8ne6r8j9aqhnmvl6rzzmz",
                Biography: "A test speaker for the event.",
                Affiliation: "AIB,BTF",
                PictureURL:  "",
            },
        },
    }
    evt.SetRenderOpts(renderOpts)
    return evt
}


func daysSincePublish() int {
    daysSincePublished := time.Since(publishedDate).Hours() / 24
    return int(daysSincePublished) + 1
}

func Render(path string) string {
	return tomorrowEvent().RenderPage(path, banner, body, overview, footer)
}

func RenderCalendar(path string) string {
	return tomorrowEvent().Render(path, eve.IcsCalendarFile)
}

func tomorrow() *time.Time {
    t := time.Now().Add(24 * time.Hour)
    return &t
}

func utc1pm() time.Time {
    t := tomorrow()
    return time.Date(t.Year(), t.Month(), t.Day(), 13, 0, 0, 0, time.UTC)
}

func utc2pm() time.Time {
    t := tomorrow()
    return time.Date(t.Year(), t.Month(), t.Day(), 14, 0, 0, 0, time.UTC)
}
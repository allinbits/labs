# Eve Events

Eve provides a reusable foundation for building, rendering, and managing event-related UI components Gnolang.

It aims for schema.org compatibility, flexible rendering (Markdown, JSON, SVG), and user interaction (buttons, links, [ICalendar](https://en.wikipedia.org/wiki/ICalendar)).

## Components Overview

The Eve package provides a set of components that can be used to create and manage event attendance, schedules, and speaker information on gno.land.

Components are configurable using the `RenderOpts` struct.

```go
renderOpts = map[string]interface{}{
    "dev": map[string]interface{}{ "SvgFooter":    struct{}{},
        "location": struct{}{},
        "speaker": struct{}{},
        "svg": struct{}{},
        "CalendarHost": "webcal://127.0.0.1:8080",
        "CalendarFile": "http://127.0.0.1:8080",
    },
    "labsnet1": map[string]interface{}{
        "location": struct{}{},
        "speaker": struct{}{},
        "svg": struct{}{},
        "SvgFooter":    struct{}{},
        "CalendarHost": "webcal://gnocal.aiblabs.net",
        "CalendarFile": "https://gnocal.aiblabs.net",
    },
}
```

Notice above - config is segmented by chainId, allowing for different configurations per chain.

### Flyer

The Flyer component is the centerpiece of the Eve package, designed to represent an event flyer document.

It includes various components such as Event, Session, Speaker, and Location, allowing for a comprehensive representation of an event.

Enable SVG view of the flyer this by setting `RenderOpts{ chainId: { "svg": struct{}{} }}`

### Calendar

ICS support is provided for calendar events, enabling users to create and manage event schedules in a standardized format.

To enable automatic syncing with ICS file URLS, a realm must expose a `RenderCalendar` method which can be used to render the event schedule in ICS format.

See [https://gnocal.aiblabs.net](https://gnocal.aiblabs.net) for more information on how to sync your calendar with the Eve package.

### Location

If your event is going to have physical or virtual locations like a room number in a building or a stream link, you can use the Location component to store that information.

Enable Location this by setting `RenderOpts{ chainId: { "location": struct{}{} }}`

### Session

Session is an important component because it is the building block of the Flyer component.
Sessions have a Title, Format, Title, and Speaker(s).

### Speaker

If your sessions are going to have speakers, you can use the Speaker component to store that information.
Speakers can have a Name, Bio, and Image URL.

Enable Speaker this by setting `RenderOpts{ chainId: { "speaker": struct{}{} }}`

### Flyer

The Flyer component is the main representation of an event, encapsulating all relevant information into a single view.

NOTE: The Flyer supports nesting content when it is rendered as markdown.

This allows content to be stored outside the Flyer component itself, and instead passed in as a variadic parameter to the `RenderMarkdown` method.

## Component Interfaces

The Eve package is built around the `Component` interface, which provides methods for rendering components in different formats.


In this codebase we have adopted a convention of aliasing the component package to `eve` for easier reference.
```go
import (
    "gno.land/p/eve000/event"
    eve "gno.land/p/eve000/event/component"
)

```

```go
type Component interface {
    ToAnchor() string
    ToMarkdown() string
    ToJson() string
    ToSVG() string
    ToSvgDataUrl() string
    RenderOpts() map[string]interface{}
}
```

A generic interface is provided to render components in different formats such as Markdown, JSON, and SVG.
```go
func RenderPage(path string, c interface{}, body ...Content) string {
	q := ParseQuery(path)
	format := q.Get("format")

	if c == nil {
		panic("RenderPage: component is nil")
	}

	switch {
	case format == "ics" && implementsIcsFileProvider(c):
		return renderIcsFile(c, body)
	case format == "json" && implementsJsonProvider(c):
		return renderJson(c, body)
	case format == "jsonld" && implementsJsonLdProvider(c):
		return renderJsonLd(c, body)
	case implementsContentProvider(c):
		return c.(ContentProvider).Render(path)
	case implementsMarkdownProvider(c):
		return c.(MarkdownProvider).ToMarkdown(body...)
	default:
		panic("RenderPage: unsupported type")
	}
}
```

Components are rendered by passing in the path, this allows each component view to alter rendering based on the context of the path.
One example of this is support for `?format=json` which can allow the inspection of each component in JSON format.


## Registry

When a realm needs to host many events or, to provide a way to update or modify events, it can use the `Registry` component.

```go

func (r *Registry) Render(path string, body ...eve.Content) string {
	u, err := url.Parse(path)
	if err != nil {
		panic("Error Parsing URL")
	}
	q := u.Query()
	event_id := q.Get("event")
	if event_id == "" {
		event_id = r.LiveEventId
	}
	return r.GetEvent(event_id).RenderPage(path, body...)
}
```

The registry provides a way to access multiple events by their ID, allowing for easy management and rendering of events.
```go
func (r *Registry) Render(path string, body ...eve.Content) string {
    u, err := url.Parse(path)
    if err != nil {
        panic("Error Parsing URL")
    }
    q := u.Query()
    event_id := q.Get("event")
    if event_id == "" {
        event_id = r.LiveEventId
    }
    return r.GetEvent(event_id).RenderPage(path, body...)
}
```
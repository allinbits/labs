# Eve Events

Eve provides a reusable foundation for building, rendering, and managing event-related UI components Gnolang.

It aims for schema.org compatibility, flexible rendering (Markdown, JSON, SVG), and user interaction (buttons, links, [ICalendar](https://en.wikipedia.org/wiki/ICalendar)).

## Components Overview

The Eve package provides a set of components that can be used to create and manage event attendance, schedules, and speaker information on gno.land.

Components are configurable using the `RenderOpts` struct.

```go
RenderOpts := RenderOpts{
    "location": struct{}{}, // Enable Location component
    "speaker": struct{}{}, // Enable Speaker component
    "svg": struct{}{}, // Enable SVG rendering of the Flyer component
}
```

### Flyer

The Flyer component is the centerpiece of the Eve package, designed to represent an event flyer document.

It includes various components such as Event, Session, Speaker, and Location, allowing for a comprehensive representation of an event.

Enable SVG view of the flyer this by setting `RenderOpts{ "svg": struct{}{} }`

### Calendar

ICS support is provided for calendar events, enabling users to create and manage event schedules in a standardized format.

Enabled by default - the realm exposes `RenderCalendar` method which can be used to render the event schedule in ICS format.

### Location

If your event is going to have physical or virtual locations like a room number in a building or a stream link, you can use the Location component to store that information.

Enable Location this by setting `RenderOpts{ "location": struct{}{} }`

### Session

Session is an important component because it is the building block of the Flyer component.
Sessions have a Title, Format, Title, and Speaker(s).

### Speaker

If your sessions are going to have speakers, you can use the Speaker component to store that information.
Speakers can have a Name, Bio, and Image URL.

Enable Speaker this by setting `RenderOpts{ "speaker": struct{}{} }`

### Flyer

The Flyer component is the main representation of an event, encapsulating all relevant information into a single view.

NOTE: The Flyer supports nesting content when it is rendered as markdown.

This allows content to be stored outside the Flyer component itself, and instead passed in as a variadic parameter to the `RenderMarkdown` method.

## Component Interfaces

The Eve package is built around the `Component` interface, which provides methods for rendering components in different formats.

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

Components are rendered by passing in the path, this allows each component view to alter rendering based on the context of the path.
One example of this is support for `?format=json` which can allow the inspection of each component in JSON format.

```go
func RenderComponent(path string, c Component) string
```

Implementing the `Page` interface only requires the `ToJson()` and `RenderMarkdown()` methods.
The `RenderMarkdown` method is used to render the page in Markdown format, which can be useful for documentation or web display.

```go
type Page interface {
    ToJson() string // schema.org compatible
    RenderMarkdown(...Content) string
}
```

RenderPage offers a similar functionality to `RenderComponent`, but it is specifically designed for rendering pages.
It also supports dual json and markdown rendering based on the format specified in path.

```go
func RenderPage(path string, c Page, body ...Content) string
```

EventSchedule puts it all together exposing the flyer and calendar rendering capabilities.

```go
type EventSchedule interface {
   ToJson() string // schema.org compatible
   RenderMarkdown(...Content) string
   RenderCalendar(string) string
   Flyer() Component
}
```

Notice that the `RenderMarkdown` method accepts a variadic parameter of type `Content` allowing for nesting content within the page.
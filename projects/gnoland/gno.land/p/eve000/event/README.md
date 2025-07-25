# Eve

Eve Package provides a structured, reusable set of components designed for building event-driven applications and presentations.

## Components Overview

These components can be used independently or integrated into larger Eve applications:

### Flyer

A featured component of Eve is the Flyer component. Once an organizer has all session dates and times finalized, they can create an flyer to share with the attendees. The agenda provides all relevant information like the Title, Description, Speaker(s), Location, & c. to the attendees. 

### Calendar

The Calendar is not fully implemented and I wouldn't consider it a "Component" yet. but if you go to an Event\_Id/calendar you will see a calendar. 

### Component

This file implements the Component interface. \

```go
type Component interface {
    ToAnchor() string
    ToMarkdown() string
    ToJson() string
    ToSVG() string
    ToSvgDataUrl() string

}
```

### Location

If your event is going to have physical or virtual locations like a room number in a building or a stream link, you can use the Location component to store that information.&#x20;

### Register

Register is not a component but actually the storage for everything. Before the organizer has even created an event, the registry is initialized to store all of the organizers events and the information therein. 

### Session

Session is an important component because it is the building block of the Flyer component. Sessions have a Title, Format, Title, and Speaker(s). Once an organizer has amassed enough of these session components then can mix-and-match them into an agenda, and publish the finalized schedule (to an agenda) when ready. 

### Speaker

If your sessions are going to have speakers, you can make them components so they render as first class objects and can even be indexed, tagged, and linked to their other relevant work. 

## Important Note on Component File Structure

In each component file (i.e., Event, Session, Speaker, Location, Flyer), the methods should be structured in the following specific order to maintain consistency and clarity:

1. **`ToAnchor()`** – Generates a web-compatible anchor link to easily navigate to specific components on a webpage.
2. **`ToMarkdown()`** – Provides a Markdown-formatted representation suitable for web display or documentation.
3. **`ToJson()`** – Outputs the component data structured as JSON, facilitating integration with APIs or frontend frameworks.
4. **`ToSVG()`** – Creates the SVG markup for visual representation.
   - **`ComponentSvg()`** (where applicable) – Helper methods to construct detailed SVG elements.
5. **`ToSvgDataUrl()`** encodes SVG markup into a data URL for embedding directly in HTML or Markdown.

## SVG Embedding


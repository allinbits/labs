# Office Hours Composition in Gno

This document explains, in practical programming terms, how the **Office
Hours** system is composed using Gno types.

------------------------------------------------------------------------

## Core Types

-   **LogoGraph** --- anything you can **render** and **hash**:
    -   `SVG() string`, `Thumbnail() string`, `JsonLD() eve.JsonLDMap`,
        `Cid() string`
-   **Projectable** --- anything you can **derive views from** using a
    URL path:
    -   `FromPath(path string) interface{}`,
        `Compose(obj interface{}) LogoGraph`,
        `ToPath(obj interface{}) string`
-   **Record** --- the stored envelope:
    -   `{ Name, Description, Cid, Object, Committer, Seq }`
-   **Schedule** --- your **event** type (implements `LogoGraph` and
    `Projectable`).
-   **calendar** --- your **calendar** type (implements `LogoGraph` and
    `Projectable`), plus an `Events` AVL of **event CIDs**.

------------------------------------------------------------------------

## Where Things Live

-   **objectStore : cid -\> Record**\
    Single source of truth. **Every object is stored exactly once.**
-   **calendarIndex : cid -\> cid**\
    Just a set of CIDs for calendars.
-   **eventIndex : cid -\> cid**\
    Just a set of CIDs for events.
-   **calendar.Events : cid -\> cid**\
    For each calendar, a set of **event CIDs** it lists.

> Indices hold **only CIDs**; dereference through `getRecord(cid)` to
> get the actual object.

------------------------------------------------------------------------

## Lifecycle

### 1) Define a calendar

``` go
var eventCalendar = calendar{
  Title:  "Gno.land Office Hours Calendar",
  Events: avl.NewTree(),
}
```

### 2) Register it

``` go
func init() {
  Register(eventCalendar, func(rec Record) {
    cal := rec.Object.(calendar)
    evt := cal.Event(rec.Cid)   // default Schedule
    evtCid := Register(evt)     // stored once

    cal.Events.Set(evtCid, evtCid)

    objectStore.Set(rec.Cid, Record{
      Name: rec.Name, Description: rec.Description, Cid: rec.Cid,
      Object: cal, Committer: rec.Committer, Seq: rec.Seq,
    })
  })
}
```

### 3) Add events

#### a) Programmatically

``` go
evt := Schedule{
  Status: "EventScheduled",
  StartDate: "2025-10-01T17:00:00Z",
  EndDate: "2025-10-01T18:00:00Z",
  Title: "Deep Dive",
  Description: "Office hours: Q&A on Logoverse patterns",
  Location: "Online",
  CalendarCid: eventCalendar.Cid(),
}
evtCid := Register(evt)

calRec, _ := getRecord(eventCalendar.Cid())
cal := calRec.Object.(calendar)
cal.Events.Set(evtCid, evtCid)
objectStore.Set(calRec.Cid, Record{ /* same fields … */ Object: cal })
```

#### b) Via Projection (URL)

    /r/labs000/officehours?base=<calCID>&submit=register
       &status=EventScheduled
       &startDate=2025-10-08T17:00:00Z
       &endDate=2025-10-08T18:00:00Z
       &location=Online
       &title=Office+Hours
       &description=Open+Q%26A
       &seal=<precomputed_event_cid>

### 4) Render objects

-   `?cal=<calendarCid>` → calendar page (`renderCalendar`).
-   `?cal=<calendarCid>&evt=<eventCid>` → event inside calendar
    (`renderEvent`).
-   `?cid=<cid>` → generic object view (with
    `v=ldjson|cid|seq|committer|svg|thumbnail|json`).

------------------------------------------------------------------------

## Guarantees

-   **No duplication:** only one `Record` per CID.
-   **Deterministic IDs:** `Cid()` = hash of `JsonLD()`.
-   **Indices safe:** only contain CIDs, never objects.
-   **Falsifiability:** `seal` must equal computed `Cid()`.

------------------------------------------------------------------------

## Quick Example

``` go
// Register calendar
Register(eventCalendar)

// Add event via projection (query string)
/r/labs000/officehours?base=<calCID>&submit=register
   &status=EventScheduled
   &startDate=2025-10-08T17:00:00Z
   &endDate=2025-10-08T18:00:00Z
   &location=Online
   &title=Office+Hours
   &description=Open+Q%26A
   &seal=<event_cid>

// Browse
/r/labs000/officehours?cal=<calCID>
/r/labs000/officehours?cal=<calCID>&evt=<evtCID>
/r/labs000/officehours?cid=<evtCID>&v=json
```

------------------------------------------------------------------------

## Extension Points

-   **Custom forms:** implement `Editable.RenderForm(path)`.
-   **Calendar views:** modify `renderCalendar` for agenda/table.\
-   **Validation:** extend `parseOhrScheduleOpts`.
-   **Multiple calendars:** register more `calendar` objects.

------------------------------------------------------------------------

## Gotchas

-   Don't put full `Schedule` in `calendar.Events`; store **CIDs** only.
-   Don't mutate objects in-place; change → new CID.
-   "Moves" = create new object and update indices.

package gnolandlaunch

import (
"gno.land/p/eve000/event"
)

func HasRole(addr string, role string) bool {
    // FIXME: lookup in acl
    return false
}

// FIXME: make sure this is changed everywher
func RenderCalendar(path string) string {
    // get the event query allback to live-event
    // build out query parames for ICS: - populate eventid if not set
    e := app.LiveEvent() // FIXME: get event specified by path

    return e.Calendar().Render(path)
}
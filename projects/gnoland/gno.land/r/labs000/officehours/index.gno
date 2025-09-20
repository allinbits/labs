package officehours

import (
	"strings"
	"time"

	"gno.land/p/eve000/event"
	eve "gno.land/p/eve000/event/component"
)

var (
	// Configuration
	eventTitle       = "Office Hours"
	eventDescription = "AibLabs Office Hours: Join us for open discussion."
	eventDayOfWeek   = time.Wednesday // e.g. time.Sunday, time.Monday, ...
	eventStartHour   = 10
	eventDuration    = time.Hour
	cancelledDates   = map[string]bool{} // YYYY-MM-DD -> true

	// Per-env render options
	renderOpts = map[string]interface{}{
		"dev": map[string]interface{}{
			"CalendarFile":  "http://127.0.0.1:8080",
			"SessionsTitle": "Next Session",
		},
		"labsnet1": map[string]interface{}{
			"SvgFooter":     struct{}{},
			"CalendarHost":  "webcal://gnocal.aiblabs.net",
			"SessionsTitle": "Next Session",
		},
	}
)

// ---------- Time helpers ----------

func nextEventDay() time.Time {
	now := time.Now().UTC()
	daysUntil := (int(eventDayOfWeek) - int(now.Weekday()) + 7) % 7
	if daysUntil == 0 {
		daysUntil = 7
	}
	next := now.AddDate(0, 0, daysUntil)
	return time.Date(next.Year(), next.Month(), next.Day(), eventStartHour, 0, 0, 0, time.UTC)
}

func isCancelled(date time.Time) bool {
	return cancelledDates[date.Format("2006-01-02")]
}

// ---------- UI helpers ----------

func proposalForm(topicCID string, s event.Schedule) string {
	// Hide after 48h past end
	if time.Now().After(event.ParseTimeSafe(s.EndDate).Add(48 * time.Hour)) {
		return ""
	}
	var sb strings.Builder
	sb.WriteString(`### Propose Topic
<gno-columns>
<gno-form>
  <gno-textarea name="description" label="Description" rows="3" required placeholder="Describe your topic proposal, or leave a comment..."/>
  <gno-input name="topic" type="radio" value="` + topicCID + `" checked="true" />
  <gno-input name="date" type="radio" value="` + s.StartDate[:10] + `" checked="true" />
</gno-form>
|||
</gno-columns>
`)
	return sb.String()
}

// ---------- Composition core ----------

// EventFromPath composes the Event (model) from the route/query.
func EventFromPath(path string) *event.Event {
	q := eve.ParseQuery(path)

	start := nextEventDay()
	end := start.Add(eventDuration)
	status := "EventPlanned"
	if isCancelled(start) {
		status = "EventCancelled"
	}

	// Optional overrides via query (non-breaking)
	if ds := q.Get("start"); ds != "" {
		if t := event.ParseTimeSafe(ds); !t.IsZero() {
			start = t
			end = start.Add(eventDuration)
		}
	}
	if de := q.Get("end"); de != "" {
		if t := event.ParseTimeSafe(de); !t.IsZero() {
			end = t
		}
	}
	if st := q.Get("status"); st != "" {
		status = st
	}

	session := &eve.Session{
		Title:       eventTitle,
		StartTime:   start,
		EndTime:     end,
		Description: eventDescription,
		Sequence:    0,
	}

	evt := &event.Event{
		Name:      eventTitle,
		Status:    eve.Status(status),
		StartDate: start,
		EndDate:   end,
		Location:  &eve.Location{Name: "Online"},
		Sessions:  []*eve.Session{session},
	}
	evt.SetRenderOpts(renderOpts)
	return evt
}

// RenderFlyer composes the flyer page view.
func RenderFlyer(path string) string {
	q := eve.ParseQuery(path)
	evt := EventFromPath(path)
	var body strings.Builder

    body.WriteString(event.Schedule{ Title: evt.Name }.Thumbnail())

	// Optional topic proposal form: ?cal=<topicCID>
	if topicCID := q.Get("cal"); topicCID != "" {
		s := event.ScheduleFromEvent(evt, topicCID)
		body.WriteString(proposalForm(topicCID, s))
	}

	return evt.RenderPage("", eve.Content{
		Published: true,
		Markdown:  body.String(),
	})
}

// RenderCalendar composes an ICS calendar file (recurring) for the event.
func RenderCalendar(path string) string {
	evt := EventFromPath(path)
	opts := map[string]string{
		"ProdId":        "-//aibLabs//Office Hours//EN",
		"CalName":       "aibLabs Office Hours",
		"CalDesc":       "Join us for open discussion.",
		"TimeZone":      "UTC",
		"Method":        "PUBLISH",
		"XWR-CALNAME":   "aibLabs Office Hours",
		"XWR-CALDESC":   "Join us for open discussion.",
		"XWR-TIMEZONE":  "UTC",
	}
	return eve.IcsRecurringCalendarFile(path, evt.Flyer(), opts)
}

// Render is the single entrypoint; it composes the correct view by route param.
func Render(path string) string {
	q := eve.ParseQuery(path)
	var sb strings.Builder

    if ics := q.Get("render"); ics == "calendar" {
        return RenderCalendar(path)
    }

	if topic := q.Get("topic"); topic != "" {
		sb.WriteString("## Commit\n")
		sb.WriteString("Topic: " + topic + "\n\n")

		if date := q.Get("date"); date != "" {
			sb.WriteString("Date: " + date + "\n\n")
		}
		if desc := q.Get("description"); desc != "" {
			sb.WriteString("Description: " + desc + "\n\n")
		}
		return sb.String()
	} else {
        evt := EventFromPath(path)
        cid := evt.Cid()
        sb.WriteString(proposalForm(cid, event.ScheduleFromEvent(evt, cid)))
	}
    return RenderFlyer(path) + sb.String()
}
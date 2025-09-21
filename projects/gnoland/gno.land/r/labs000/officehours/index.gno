package officehours

import (
    "std"
    "strconv"
	"strings"
	"time"

	"gno.land/p/eve000/event"
	eve "gno.land/p/eve000/event/component"
)

type OfficeHours struct {
	eventTitle       string
	eventDescription string
	eventDayOfWeek   time.Weekday
	eventStartHour   int
	eventDuration    time.Duration
	cancelledDates   map[string]bool
	renderOpts       map[string]interface{}
	sequence         int
	admin            string
}

// format as json
func (o *OfficeHours) String() string {
    return `{
    "eventTitle": "` + o.eventTitle + `",
    "eventDescription": "` + o.eventDescription + `",
    "eventDayOfWeek": "` + o.eventDayOfWeek.String() + `",
    "eventStartHour": ` + strconv.Itoa(o.eventStartHour) + `,
    "eventDurationMinutes": ` + strconv.Itoa(int(o.eventDuration.Minutes())) + `,
    "cancelledDates": ` + func() string {
        var dates []string
        for d := range o.cancelledDates {
            dates = append(dates, `"`+d+`"`)
        }
        return "[" + strings.Join(dates, ", ") + "]"
    }() + `,
    "admin": "` + o.admin + `",
    "sequence": ` + strconv.Itoa(o.sequence) + `
}`
}

var officeHours *OfficeHours

func init() {
	officeHours = &OfficeHours{
		eventTitle:       "",
		eventDescription: "",
		eventDayOfWeek:   time.Sunday,
		eventStartHour:   1,
		eventDuration:    time.Hour,
		cancelledDates:   map[string]bool{},
		renderOpts: map[string]interface{}{
			"dev": map[string]interface{}{
				"CalendarFile":  "http://127.0.0.1:8080",
				"SessionsTitle": "Next Session",
			},
			"labsnet1": map[string]interface{}{
				"SvgFooter":     struct{}{},
				"CalendarFile":  "https://gnocal.aiblabs.net",
				"SessionsTitle": "Next Session",
			},
		},
		sequence: -1,
		admin:    std.PreviousRealm().Address().String(), // initial admin is the deployer
	}

	officeHours.Update(
        "eventTitle", "Office Hours",
        "eventDescription", "Join us for open discussion.",
        "eventDayOfWeek", "wednesday",
        "eventStartHour", "10",
        "eventDurationMinutes", "60",
        "cancelledDate", "2024-12-25",
        "cancelledDate", "2024-10-25",
    )
}

func assertAccess() {
	if officeHours.admin != std.PreviousRealm().Address().String() {
		panic("access denied")
	}
}

func Update(_ realm, parts ...string) {
    assertAccess()
    officeHours.Update(parts...)
}

var validKeys = map[string]bool{
    "admin":         true,
    "eventTitle":    true,
    "eventDescription": true,
    "eventDayOfWeek": true,
    "eventStartHour": true,
    "eventDurationMinutes": true,
    "cancelledDate": true,
}

func (OfficeHours) Update(parts ...string) {
    if len(parts)%2 != 0 || len(parts) == 2 {
        panic("Update requires key-value pairs")
    }
    officeHours.sequence++
    for i := 0; i < len(parts); i += 2 {
        key := strings.TrimSpace(parts[i])
        if !validKeys[key] {
            panic("Invalid key: " + key + ". Valid keys are: admin, eventTitle, eventDescription, eventDayOfWeek, eventStartHour, eventDurationMinutes, cancelledDate")
        }
        value := strings.TrimSpace(parts[i+1])

        switch key {
        case "admin":
            officeHours.admin = value
        case "eventTitle":
            officeHours.eventTitle = value
        case "eventDescription":
            officeHours.eventDescription = value
        case "eventDayOfWeek":
            switch strings.ToLower(value) {
            case "sunday":
                officeHours.eventDayOfWeek = time.Sunday
            case "monday":
                officeHours.eventDayOfWeek = time.Monday
            case "tuesday":
                officeHours.eventDayOfWeek = time.Tuesday
            case "wednesday":
                officeHours.eventDayOfWeek = time.Wednesday
            case "thursday":
                officeHours.eventDayOfWeek = time.Thursday
            case "friday":
                officeHours.eventDayOfWeek = time.Friday
            case "saturday":
                officeHours.eventDayOfWeek = time.Saturday
            default:
                panic("Invalid day of week")
            }
        case "eventStartHour":
            if h, err := strconv.Atoi(value); err == nil && h >= 0 && h < 24 {
                officeHours.eventStartHour = h
            } else {
                panic("Invalid start hour")
            }
        case "eventDurationMinutes":
            if m, err := strconv.Atoi(value); err == nil && m > 0 {
                officeHours.eventDuration = time.Duration(m) * time.Minute
            } else {
                panic("Invalid duration minutes")
            }
        case "cancelledDate":
            if _, err := time.Parse("2006-01-02", value); err == nil {
                officeHours.cancelledDates[value] = true
            } else {
                panic("Invalid date format for cancelledDate. Use YYYY-MM-DD.")
            }
        }
    }
}

// ---------- Time helpers ----------

func nextEventDay() time.Time {
	now := time.Now().UTC()
	daysUntil := (int(officeHours.eventDayOfWeek) - int(now.Weekday()) + 7) % 7
	if daysUntil == 0 {
		daysUntil = 7
	}
	next := now.AddDate(0, 0, daysUntil)
	return time.Date(next.Year(), next.Month(), next.Day(), officeHours.eventStartHour, 0, 0, 0, time.UTC)
}

func isCancelled(date time.Time) bool {
	return officeHours.cancelledDates[date.Format("2006-01-02")]
}

// ---------- UI helpers ----------

func proposalForm(topicCID string, s event.Schedule) string {
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

func EventFromPath(path string) *event.Event {
	q := eve.ParseQuery(path)
	_ = q // TODO: allow user to skip ahead to future events
	start := nextEventDay()

	end := start.Add(officeHours.eventDuration)
	status := "EventPlanned"

	if isCancelled(start) {
		status = "EventCancelled"
	}

	session := &eve.Session{
		Title:       officeHours.eventTitle,
		StartTime:   start,
		EndTime:     end,
		Description: officeHours.eventDescription,
		Sequence:    officeHours.sequence,
	}

	evt := &event.Event{
		Name:      officeHours.eventTitle,
		Status:    eve.Status(status),
		StartDate: start,
		EndDate:   end,
		Location:  &eve.Location{Name: "Online"},
		Sessions:  []*eve.Session{session},
	}
	evt.SetRenderOpts(officeHours.renderOpts)
	return evt
}

// RenderFlyer composes the flyer page view.
func RenderFlyer(path string) string {
	q := eve.ParseQuery(path)
	evt := EventFromPath(path)
	var body strings.Builder

	body.WriteString(event.Schedule{Title: evt.Name}.Thumbnail())

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
		"ProdId":       "-//aibLabs//Office Hours//EN",
		"CalName":      "aibLabs Office Hours",
		"CalDesc":      "Join us for open discussion.",
		"TimeZone":     "UTC",
		"Method":       "PUBLISH",
		"XWR-CALNAME":  "aibLabs Office Hours",
		"XWR-CALDESC":  "Join us for open discussion.",
		"XWR-TIMEZONE": "UTC",
	}
	return eve.IcsRecurringCalendarFile(path, evt.Flyer(), opts)
}

// Render is the single entrypoint; it composes the correct view by route param.
func Render(path string) string {
	q := eve.ParseQuery(path)
	var sb strings.Builder

    if q.Get("format") == "json" {
        return officeHours.String()
    }

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
package officehours

import (
	"std"
	"strconv"
	"strings"
	"time"

	"gno.land/p/eve000/event"
	eve "gno.land/p/eve000/event/component"
	"gno.land/p/moul/txlink"
)

// ---------- Constants & Types ----------

var publishedAt = time.Date(2025, 9, 1, 0, 0, 0, 0, time.UTC)

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
	selectedDate     string
}

// ---------- State ----------

var officeHours = &OfficeHours{
	eventTitle:       "",
	eventDescription: "",
	eventDayOfWeek:   time.Sunday,
	eventStartHour:   1,
	eventDuration:    time.Hour,
	cancelledDates:   map[string]bool{},
	renderOpts: map[string]any{
		"dev": map[string]any{
			"CalendarFile":  "http://127.0.0.1:8080",
			"SessionsTitle": "Weekly Session",
		},
		"labsnet1": map[string]any{
			"CalendarFile":  "https://gnocal.aiblabs.net",
			"SessionsTitle": "Weekly Session",
		},
	},
	sequence:     -1,
	admin:        std.PreviousRealm().Address().String(),
	selectedDate: "2025-09-01",
}

// ---------- Access Control ----------

func assertAccess() {
	if officeHours.admin != std.PreviousRealm().Address().String() {
		panic("access denied: only admin can update office hours")
	}
}

// ---------- OfficeHours Methods ----------

func (o *OfficeHours) String() string {
	return `{
    "eventTitle": "` + o.eventTitle + `",
    "eventDescription": "` + o.eventDescription + `",
    "eventDayOfWeek": "` + o.eventDayOfWeek.String() + `",
    "eventStartHour": ` + strconv.Itoa(o.eventStartHour) + `,
    "eventDurationMinutes": ` + strconv.Itoa(int(o.eventDuration.Minutes())) + `,
    "cancelledDates": ` + formatCancelledDates(o.cancelledDates) + `,
    "admin": "` + o.admin + `",
    "sequence": ` + strconv.Itoa(o.sequence) + `
}`
}

func formatCancelledDates(dates map[string]bool) string {
	var list []string
	for d := range dates {
		list = append(list, `"`+d+`"`)
	}
	return "[" + strings.Join(list, ", ") + "]"
}

// ---------- Update Logic ----------

var validKeys = map[string]bool{
	"admin":                true,
	"eventTitle":           true,
	"eventDescription":     true,
	"eventDayOfWeek":       true,
	"eventStartHour":       true,
	"eventDurationMinutes": true,
	"cancelledDate":        true,
}

// Update modifies the office hours configuration.
func Update(cur realm, parts ...string) {
	assertAccess()
	officeHours.Update(parts...)
}

func (o *OfficeHours) Update(parts ...string) {
	if len(parts)%2 != 0 || len(parts) < 2 {
		panic("Update requires key-value pairs")
	}
	o.sequence++
	for i := 0; i < len(parts); i += 2 {
		key := strings.TrimSpace(parts[i])
		if !validKeys[key] {
			panic("Invalid key: " + key + ". Valid keys: admin, eventTitle, eventDescription, eventDayOfWeek, eventStartHour, eventDurationMinutes, cancelledDate")
		}
		value := strings.TrimSpace(parts[i+1])
		o.applyUpdate(key, value)
	}
}

func (o *OfficeHours) applyUpdate(key, value string) {
	switch key {
	case "admin":
		o.admin = value
	case "eventTitle":
		o.eventTitle = value
	case "eventDescription":
		o.eventDescription = value
	case "eventDayOfWeek":
		o.eventDayOfWeek = parseWeekday(value)
	case "eventStartHour":
		o.eventStartHour = parseHour(value)
	case "eventDurationMinutes":
		o.eventDuration = parseDurationMinutes(value)
	case "cancelledDate":
		o.cancelledDates[parseCancelledDate(value)] = true
	}
}

func parseWeekday(value string) time.Weekday {
	switch strings.ToLower(value) {
	case "sunday":
		return time.Sunday
	case "monday":
		return time.Monday
	case "tuesday":
		return time.Tuesday
	case "wednesday":
		return time.Wednesday
	case "thursday":
		return time.Thursday
	case "friday":
		return time.Friday
	case "saturday":
		return time.Saturday
	default:
		panic("Invalid day of week: " + value)
	}
}

func parseHour(value string) int {
	h, err := strconv.Atoi(value)
	if err != nil || h < 0 || h > 23 {
		panic("Invalid start hour: " + value)
	}
	return h
}

func parseDurationMinutes(value string) time.Duration {
	m, err := strconv.Atoi(value)
	if err != nil || m <= 0 {
		panic("Invalid duration minutes: " + value)
	}
	return time.Duration(m) * time.Minute
}

func parseCancelledDate(value string) string {
	if _, err := time.Parse("2006-01-02", value); err != nil {
		panic("Invalid date format for cancelledDate. Use YYYY-MM-DD.")
	}
	return value
}

// ---------- Time Helpers ----------

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

// ---------- UI Helpers ----------

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
	nextDate := event.ParseTimeSafe(s.StartDate).AddDate(0, 0, 7).Format("2006-01-02")
	sb.WriteString("\n[Next date →](" + "?date=" + nextDate + ")\n")
	return sb.String()
}

// ---------- Event Composition ----------

func eventFromPath(path string) *event.Event {
	q := eve.ParseQuery(path)
	var start time.Time

	if dateStr := q.Get("date"); dateStr != "" {
		parsed, err := time.Parse("2006-01-02", dateStr)
		if err == nil {
			start = time.Date(parsed.Year(), parsed.Month(), parsed.Day(), officeHours.eventStartHour, 0, 0, 0, time.UTC)
		} else {
			start = nextEventDay()
		}
	} else {
		start = nextEventDay()
	}

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

// ---------- Renderers ----------

func renderFlyer(path string) string {
	q := eve.ParseQuery(path)
	evt := eventFromPath(path)
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
// Objects are language, not files -  we keep a tiny semantic core and project canonical views on demand.
func RenderCalendar(path string) string {
	opts := map[string]any{
		"Location": "Online",
		"Freq":     "WEEKLY",
		"ByDay":    strings.ToUpper(officeHours.eventDayOfWeek.String()[:2]),
		"Interval": 1,
		"DtStart":  publishedAt.Format("20060102T150405Z"),
		"Until":    "20261231T000000Z", // REVIEW: make configurable?
		"ExDates":  []string{},
	}

	for date, _ := range officeHours.cancelledDates {
		if t, err := time.Parse("2006-01-02", date); err == nil {
			exdate := time.Date(t.Year(), t.Month(), t.Day(), officeHours.eventStartHour, 0, 0, 0, time.UTC)
			opts["ExDates"] = append(opts["ExDates"].([]string), exdate.Format("20060102T150405Z"))
		}
	}

	return eve.IcsRecurringCalendarFile(path, opts)
}

// Render is the main entry point to render the office hours page.
// | ?embed=banner | to render a markdown banner with a link to the flyer image. (useful from other realms)
// | ?embed=thumbnail | to render a markdown thumbnail with a link to the flyer image. (useful from other realms)
// | ?format=json | to view the current configuration in JSON.
// | ?render=calendar | to view the ICS calendar file.
// | ?topic=CID&date=YYYY-MM-DD&description={str} | to view a topic proposal confirmation.
// otherwise, it renders the flyer with a proposal form.
func Render(path string) string {
	q := eve.ParseQuery(path)
	var sb strings.Builder
	link := packagePath[9:]

	switch {
	case q.Get("embed") == "thumbnail":
		return "[" + officeHours.Thumbnail() + "](/" + link + ")\n\n"
	case q.Get("embed") == "banner":
		return "[![Event Flyer](" + officeHours.DataUrl() + ")](/" + link + ")\n\n"
	case q.Get("format") == "json":
		return officeHours.JsonLD().StringWithCID()
	case q.Get("render") == "calendar":
		return "```\n" + RenderCalendar(path) + "\n```"
	case q.Get("topic") != "":
		sb.WriteString(renderTopicConfirm(q))
	default:
		evt := eventFromPath(path)
		cid := evt.Cid()
		sb.WriteString(proposalForm(cid, event.ScheduleFromEvent(evt, cid)))
	}
	return renderFlyer(path) + sb.String()
}

func renderTopicConfirm(q eve.Query) string {
	var sb strings.Builder
	sb.WriteString("## Confirm\n")
	sb.WriteString("Submit your topic proposal by posting a transaction with the following parameters:\n\n---\n\n")
	sb.WriteString("Func: PostTopic\n\n")
	sb.WriteString("Topic: " + q.Get("topic") + "\n\n")

	if date := q.Get("date"); date != "" {
		sb.WriteString("Date: " + date + "\n\n")
		if desc := q.Get("description"); desc != "" {
			sb.WriteString("Description: " + desc + "\n\n---\n\n")
			sb.WriteString(showCLI(q.Get("topic"), date, desc))
		} else {
			sb.WriteString("> [!CAUTION]\n> Missing description parameter\n\n")
		}
	} else {
		sb.WriteString("> [!CAUTION]\n> Missing date parameter\n\n")
	}
	return sb.String()
}

// ---------- CLI Helpers ----------

func showCLI(topic, date, description string) string {
	var sb strings.Builder
	link := txlink.NewLink("PostTopic").AddArgs(
		"CID", topic,
		"date", date,
		"description", description,
	).URL()

	sb.WriteString("#### Txlink Button (Adena Wallet) \n\n")
	sb.WriteString("Click the button below to open Adena Wallet and prefill a transaction:\n\n")
	sb.WriteString("EXPERIMENTAL: Adena support is still being tested (looking for feedback here).\n\n")
	sb.WriteString(eve.Button("Post Topic  ", link))
	sb.WriteString("\n\n[" + link + "](" + link + ")\n\n")
	return cliCommand(topic, date, description) + "\n\n" + sb.String()
}

func cliCommand(topic, date, description string) string {
	var sb strings.Builder
	sb.WriteString("#### CLI Command (Gnokey) \n\n")
	sb.WriteString("\n```\n\n")
	sb.WriteString("gnokey maketx call ")
	sb.WriteString(" -pkgpath \"" + std.CurrentRealm().PkgPath() + "\"")
	sb.WriteString(" -func \"PostTopic\"")
	sb.WriteString(" -args \"" + topic + "\"")
	sb.WriteString(" -args \"" + date + "\"")
	sb.WriteString(" -args \"" + description + "\"")
	sb.WriteString(" -gas-fee 1000000ugnot ")
	sb.WriteString(" -gas-wanted 5000000 ")
	sb.WriteString(" -send \"\" ")
	sb.WriteString(" -broadcast ")
	sb.WriteString(" -chainid \"" + std.ChainID() + "\" ")
	sb.WriteString(" -remote \"tcp://0.0.0.0:26657\" ")
	sb.WriteString(" ADDRESS")
	sb.WriteString("\n```")
	return sb.String()
}

// ---------- Event Posting ----------

// PostTopic is the function to be called in a transaction to propose a topic for the next office hours.
// This function emits an event that is indexed by the realm owner to build a list of proposed topics and review comments.
func PostTopic(cur realm, CID, date, description string) {
	eve.MustCIDv1("topic", CID)
	std.Emit("officehours-topic",
		"topic", CID,
		"date", date,
		"description", description,
	)
}

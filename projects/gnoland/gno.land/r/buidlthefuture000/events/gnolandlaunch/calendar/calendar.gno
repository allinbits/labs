package calendar

import (
	"net/url"
	"regexp"
	"strings"
	"time"

	"gno.land/p/demo/ufmt"
)

const (
	// feedDomain is the fixed URL path for subscription
	feedDomain = "gno.land/r/buidlthefuture000/events/gnolandlaunch"
)

var f = ufmt.Sprintf

// Session is your event type with sequence and cancellation flags.
type Session struct {
	Title       string
	Description string
	Speaker     string
	StartTime   time.Time
	EndTime     time.Time
	Location    string
	Sequence    int  // bumped on every edit
	Cancelled   bool // mark true to cancel
}

// sanitize returns a lowercase slug of the title.
func sanitize(s string) string {
	re := regexp.MustCompile(`[^a-z0-9]+`)
	slug := strings.ToLower(s)
	slug = re.ReplaceAllString(slug, "-")
	slug = strings.Trim(slug, "-")
	return slug
}

func (s *Session) ToICAL() string {
	lines := []string{
		"BEGIN:VEVENT",
		f("UID:%s-%d@%s", sanitize(s.Title)[:5], s.StartTime.Unix(), feedDomain),
		f("SEQUENCE:%d", s.Sequence),
		f("DTSTAMP:%s", time.Now().UTC().Format("20060102T150405Z")),
		f("DTSTART:%s", s.StartTime.UTC().Format("20060102T150000Z")),
		f("DTEND:%s", s.EndTime.UTC().Format("20060102T150000Z")),
		"SUMMARY:" + s.Title,
		"DESCRIPTION:" + s.Description,
		"LOCATION:" + s.Location,
	}
	if s.Cancelled {
		lines = append(lines, "STATUS:CANCELLED")
	}
	lines = append(lines, "END:VEVENT")
	return strings.Join(lines, "\n") + "\n"
}

// BuildCalendar wraps all sessions into one VCALENDAR.
func BuildCalendar(m map[string]*Session) string {
	header := strings.Join([]string{
		"BEGIN:VCALENDAR",
		"VERSION:2.0",
		"CALSCALE:GREGORIAN",
		"PRODID:-//gno.land//Launch Calendar//EN",
		"METHOD:PUBLISH",
	}, "\n") + "\n\n"
	footer := "\nEND:VCALENDAR"

	parts := make([]string, 0, len(m)+2)
	for _, sess := range m {
		parts = append(parts, sess.ToICAL())
	}
	return header + strings.Join(parts, "\n") + footer
}

var sessions = map[string]*Session{
	"generics": {
		Title:       "Generics in Action: Simplifying Go Code",
		Description: "Learn practical use cases for Go generics to simplify and enhance your code.",
		Speaker:     "alice",
		StartTime:   time.Date(2025, 5, 26, 10, 0, 0, 0, time.UTC),
		EndTime:     time.Date(2025, 5, 26, 11, 30, 0, 0, time.UTC),
		Location:    "room-a1",
	},
	"concurrency": {
		Title:       "Concurrency Patterns in Real-World Applications",
		Description: "A deep dive into concurrency patterns to efficiently handle complex workflows.",
		Speaker:     "bob",
		StartTime:   time.Date(2025, 5, 27, 13, 0, 0, 0, time.UTC),
		EndTime:     time.Date(2025, 5, 27, 14, 30, 0, 0, time.UTC),
		Location:    "room-b2",
	},
	"apis": {
		Title:       "Building High-Performance APIs with Go",
		Description: "Techniques and best practices for building scalable and performant APIs.",
		Speaker:     "carol",
		StartTime:   time.Date(2025, 5, 28, 15, 0, 0, 0, time.UTC),
		EndTime:     time.Date(2025, 5, 28, 16, 30, 0, 0, time.UTC),
		Location:    "room-c3",
	},
}

func Render(path string) string {
	// Generate v1
	v1 := BuildCalendar(sessions)
	url1 := "data:text/calendar;charset=utf-8," + url.PathEscape(v1)
	link1 := f("[Download v1 ICS](%s)", url1)

	// Update generics
	sessions["generics"].Description = "Updated description!"
	sessions["generics"].Sequence++
	v2 := BuildCalendar(sessions)
	url2 := "data:text/calendar;charset=utf-8," + url.PathEscape(v2)
	link2 := f("[Download v2 ICS](%s)", url2)

	// Cancel generics
	sessions["generics"].Cancelled = true
	sessions["generics"].Sequence++
	v3 := BuildCalendar(sessions)
	url3 := "data:text/calendar;charset=utf-8," + url.PathEscape(v3)
	link3 := f("[Download v3 ICS](%s)", url3)

	out := f("## Calendar v1\n```ics\n%s\n```\n%s\n\n## Calendar v2\n```ics\n%s\n```\n%s\n\n## Calendar v3\n```ics\n%s\n```\n%s",
		v1, link1,
		v2, link2,
		v3, link3,
	)
	return out
}

type VEvent struct {
	UID         string
	DtStamp     string
	Summary     string
	Description string
	DtStart     string
	DtEnd       string
	Location    string
}

type VCalendar struct {
	ProdID   string
	CalName  string
	TimeZone string
	Method   string
	Events   []VEvent
}

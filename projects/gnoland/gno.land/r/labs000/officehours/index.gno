package officehours

	import (
		"strings"
		"time"

		"gno.land/p/eve000/event"
		eve "gno.land/p/eve000/event/component"
	)

	var (
		eventTitle       = "Office Hours"
		eventDescription = "AibLabs Office Hours: Join us for open discussion."
		eventDayOfWeek   = time.Wednesday // Configurable: time.Sunday, time.Monday, etc.
		eventStartHour   = 10
		eventDuration    = time.Hour
		cancelledDates   = map[string]bool{} // Example: YYYY-MM-DD format
	)

	func nextEventDay() time.Time {
		now := time.Now().UTC()
		daysUntilEvent := (int(eventDayOfWeek) - int(now.Weekday()) + 7) % 7
		if daysUntilEvent == 0 {
			daysUntilEvent = 7
		}
		nextEvent := now.AddDate(0, 0, daysUntilEvent)
		return time.Date(nextEvent.Year(), nextEvent.Month(), nextEvent.Day(), eventStartHour, 0, 0, 0, time.UTC)
	}

	func isCancelled(date time.Time) bool {
		dateStr := date.Format("2006-01-02")
		if _, exists := cancelledDates[dateStr]; exists {
			return true
		}
		return false
	}

    func proposalForm(cid string, evt event.Schedule) string {
        if time.Now().After(event.ParseTimeSafe(evt.EndDate).Add(48 * time.Hour)) {
            return ""
        }
        var sb strings.Builder
        sb.WriteString(`### Propose Topic
<gno-columns>
<gno-form>
    <gno-textarea name="description" label="Description" rows="3" required placeholder="Describe your topic proposal, Or leave a comment here..."/>
    <gno-input name="topic" type="radio" value="` + cid + `" checked="true" />
    </gno-form>

|||

</gno-columns>
`)
        return sb.String()
    }

	func Render(path string) string {
		q := eve.ParseQuery(path)
		var sb strings.Builder

		if topic, ok := q["topic"]; ok && len(topic) > 0 {
			sb.WriteString("## Commit \n Topic: " + topic[0] + "\n\n")
            if description, ok := q["description"]; ok && len(description) > 0 {
                sb.WriteString("Description: " + description[0] + "\n\n")
                return sb.String()
            }
		}

		startDate := nextEventDay()
		endDate := startDate.Add(eventDuration)
		status := "EventPlanned"
		if isCancelled(startDate) {
			status = "EventCancelled"
		}

		options := map[string]string{
			"Status":      status,
			"StartDate":   startDate.Format(time.RFC3339),
			"EndDate":     endDate.Format(time.RFC3339),
			"Title":       eventTitle,
			"Description": eventDescription,
		}

		return event.Calendar(options, event.WithCommentForm(proposalForm)).Render(path)
	}
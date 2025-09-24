package officehours

func init() { Init() }

// Init applies changeset updates to the officeHours variable.
// This allows us to manage the calendar with code (instead of Update transactions),
// and ensures changes still increment the sequence number (so calendars stay in sync).
func Init() {
	assertAccess()
	officeHours.Update( // seq=0
		"eventTitle", "Office Hours",
		"eventDescription", "Join us for open discussion.",
		"eventDayOfWeek", "wednesday",
		"eventStartHour", "10",
		"eventDurationMinutes", "60",
	)
	// REVIEW: add more updates here as needed.
	officeHours.Update( // seq=1
		"cancelledDate", "2024-12-25",
		"cancelledDate", "2024-10-25",
	)
}

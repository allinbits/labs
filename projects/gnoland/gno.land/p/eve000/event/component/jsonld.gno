package component

import (
	"strings"

	"gno.land/p/demo/ufmt"
)

const DateFormatJsonLD = "2006-01-02T15:04:05-07:00"

func EventJsonLD(_ string, a *Flyer) string {
	var sb strings.Builder
	sb.WriteString(`{
        "@context": "https://schema.org",
        "@type": "Event",
        "name": "` + ufmt.Sprintf("%s", a.Name) + `",`)

	if a.Status == EventPostponed {
		sb.WriteString(`
        "previousStartDate": "` + ufmt.Sprintf("%s", a.StartDate.Format(DateFormatJsonLD)) + `",`)
	} else {
		sb.WriteString(`
        "startDate": "` + ufmt.Sprintf("%s", a.StartDate.Format(DateFormatJsonLD)) + `",`)
		sb.WriteString(`
        "endDate": "` + ufmt.Sprintf("%s", a.EndDate.Format(DateFormatJsonLD)) + `",`)
	}

	sb.WriteString(`
        "eventAttendanceMode": "` + ufmt.Sprintf("%s", a.AttendanceMode) + `",
        "eventStatus": "` + ufmt.Sprintf("%s", a.Status) + `",`)

	if a.AttendanceMode != OfflineEventAttendanceMode && a.Location != nil {
		sb.WriteString(`
        "location": {
            "@type": "Place",
            "name": "` + ufmt.Sprintf("%s", a.Location.Name) + `"
        },`)
	}

	// Add images if available
	sb.WriteString(`
        "image": [`)
	for i, img := range a.Images {
		if i > 0 {
			sb.WriteString(",")
		}
		sb.WriteString(`"` + ufmt.Sprintf("%s", img) + `"`)
	}
	sb.WriteString(`],`)

	sb.WriteString(`
        "description": "` + ufmt.Sprintf("%s", a.Description) + `"
    }`)
	return sb.String()
}

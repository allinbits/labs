package officehours

import (
	"strconv"
	"strings"
	"time"

	"gno.land/p/eve000/event"
	eve "gno.land/p/eve000/event/component"
)

// TODO: consider adding another realm to host dynamic event creation/editing UIs.

// ApplyURLDetails copies known Event/Session/Speaker fields from opts (typically
// parsed from the URL query) onto evt.
//
// Top-level event keys (case-insensitive):
//
//	name, description, status, startDate (RFC3339 or time.Time), endDate
//
// Session & speaker keys use s{index}_prefix:
//
//	s0_title, s0_body, s0_start, s0_end,
//	s0_speaker_name, s0_speaker_address, s0_speaker_affiliation, s0_speaker_bio
//
// Example:
//
//	?name=Intro&description=Logoverse&status=EventScheduled&
//	startDate=2025-06-01T00:00:00Z&endDate=2025-06-01T01:00:00Z&
//	s0_title=What%20is%20the%20Logoverse%3F&
//	s0_body=-%20Bullets%20in%20markdown&
//	s0_speaker_name=Matt%20York&
//	s0_speaker_affiliation=[allinbits.com](https://allinbits.com)&
//	s0_speaker_bio=[gh/stackdump](https://github.com/stackdump)
func ApplyURLDetails(evt *event.Event, opts map[string]any) {
	// ---- Event fields ----
	if v, ok := getStringCI(opts, "name"); ok {
		evt.Name = v
	}
	if v, ok := getStringCI(opts, "description", "desc"); ok {
		evt.Description = v
	}
	if v, ok := getStringCI(opts, "status"); ok {
		evt.Status = eve.Status(v)
	}
	if t, ok := getTimeCI(opts, "startDate", "start"); ok {
		evt.StartDate = t
		for _, s := range evt.Sessions {
			s.StartTime = t
		}
	}
	if t, ok := getTimeCI(opts, "endDate", "end"); ok {
		evt.EndDate = t
		for _, s := range evt.Sessions {
			s.EndTime = t
		}
	}

	// ---- Session & Speaker fields ----
	// Support s{index}_field naming. If there are no sessions yet but we see s0_*,
	// create one so URL-only definitions can work.
	ensureSessionIfNeeded(evt, opts)

	for i, s := range evt.Sessions {
		prefix := "s" + strconv.Itoa(i) + "_"

		if v, ok := getString(opts, prefix+"title"); ok {
			s.Title = v
		}
		if md, ok := getString(opts, prefix+"body"); ok {
			s.Body = []eve.Content{{Published: true, Markdown: md}}
		}
		if t, ok := getTime(opts, prefix+"start"); ok {
			s.StartTime = t
		}
		if t, ok := getTime(opts, prefix+"end"); ok {
			s.EndTime = t
		}

		// Speaker details (create speaker if needed)
		if s.Speaker == nil {
			s.Speaker = &eve.Speaker{}
		}
		if v, ok := getString(opts, prefix+"speaker_name"); ok {
			s.Speaker.Name = v
		}
		if v, ok := getString(opts, prefix+"speaker_address"); ok {
			s.Speaker.Address = v
		}
		if v, ok := getString(opts, prefix+"speaker_affiliation"); ok {
			s.Speaker.Affiliation = v
		}
		if v, ok := getString(opts, prefix+"speaker_bio"); ok {
			s.Speaker.Biography = v
		}
	}
}

/* ---------- tiny helpers (no reflection; Gno-friendly) ---------- */

func ensureSessionIfNeeded(evt *event.Event, opts map[string]any) {
	if len(evt.Sessions) > 0 {
		return
	}
	// If URL contains any s0_* keys, create the first session.
	hasS0 := false
	for k := range opts {
		if strings.HasPrefix(k, "s0_") {
			hasS0 = true
			break
		}
	}
	if hasS0 {
		evt.Sessions = []*eve.Session{{}}
	}
}

func getString(opts map[string]any, key string) (string, bool) {
	if v, ok := opts[key]; ok {
		switch x := v.(type) {
		case string:
			if x != "" {
				return x, true
			}
		}
	}
	return "", false
}

func getStringCI(opts map[string]any, keys ...string) (string, bool) {
	// Case-insensitive lookup with aliases.
	co := canonKeys(opts)
	for _, k := range keys {
		if v, ok := co[strings.ToLower(k)]; ok && v != "" {
			return v, true
		}
	}
	return "", false
}

func getTime(opts map[string]any, key string) (time.Time, bool) {
	if v, ok := opts[key]; ok {
		switch x := v.(type) {
		case time.Time:
			return x, true
		case string:
			if t, err := time.Parse(time.RFC3339, x); err == nil {
				return t, true
			}
		}
	}
	return time.Time{}, false
}

func getTimeCI(opts map[string]any, keys ...string) (time.Time, bool) {
	co := canonKeys(opts)
	for _, k := range keys {
		if raw, ok := co[strings.ToLower(k)]; ok {
			// Attempt as RFC3339
			if t, err := time.Parse(time.RFC3339, raw); err == nil {
				return t, true
			}
		}
	}
	return time.Time{}, false
}

func canonKeys(opts map[string]any) map[string]string {
	out := make(map[string]string, len(opts))
	for k, v := range opts {
		lk := strings.ToLower(k)
		switch x := v.(type) {
		case string:
			out[lk] = x
		case time.Time:
			out[lk] = x.UTC().Format(time.RFC3339)
		default:
			// ignore non-stringy values here
		}
	}
	return out
}

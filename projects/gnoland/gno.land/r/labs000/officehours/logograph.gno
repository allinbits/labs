package officehours

import (
    "std"
    "net/url"

	"gno.land/p/eve000/event"
	eve "gno.land/p/eve000/event/component"
)

// ---------- Logograph / Projectable / Editable surface ----------

var (
	_ eve.LogoGraph  = officeHours
	_ eve.Projectable = officeHours
	_ eve.Editable   = officeHours
)

func init() {
   eve.AssertProjectionRoundTrip(officeHours, officeHours)
}

// Cid is derived from the stable JSON-LD composed below.
func (o OfficeHours) Cid() string {
	return o.JsonLD().Cid()
}

// RenderForm (HTML) → form to propose a new session.
func (OfficeHours) RenderForm(path string) string {
	evt := eventFromPath(path)
	cid := evt.Cid()
	return proposalForm(cid, event.ScheduleFromEvent(evt, cid))
}

// Image (markdown) → embeds the full SVG via data URL.
func (o OfficeHours) Image() string {
	return "![OfficeHours](" + o.DataUrl() + ")"
}

func (o OfficeHours) DataUrl() string {
	return "data:image/svg+xml;charset=utf-8," + url.PathEscape(o.SVG())
}

func (OfficeHours) Thumbnail() string {
	return "![OfficeHours](" + OfficeHours{}.ThumbnailDataUrl() + ")"
}

func (OfficeHours) ThumbnailDataUrl() string {
	return "data:image/svg+xml;utf8," + url.PathEscape(OfficeHours{}.ThumbnailSvg("75", "94"))
}

func (OfficeHours) ThumbnailSvg(w, h string) string {
	encoded := url.PathEscape(OfficeHours{}.SVG())
	id := OfficeHours{}.Cid()
	return `<svg id="` + id + `" width="` + w + `" height="` + h + `" xmlns="http://www.w3.org/2000/svg">
  <g>
    <rect x="4" y="0" width="` + w + `" height="` + h + `" fill="#fff" stroke="#ccc" stroke-width="1"/>
    <path d="M4,0 l12,0 l-12,12 z" fill="#f0f0f0" stroke="#ccc" stroke-width="1"/>
  </g>
  <text x="12" y="` + h + `" font-size="14" font-weight="bold" fill="#666" dominant-baseline="ideographic">OfficeHours</text>
  <image href="data:image/svg+xml;utf8,` + encoded + `" x="12" y="5"
         width="calc(` + w + ` - 24)" height="calc(` + h + ` - 32)"/>
</svg>`
}

// SVG returns the full SVG representation of the flyer.
func (o OfficeHours) SVG() string {
	return o.Flyer().ToSVG()
}

// mergeOpts lets you override transient view options before composing JSON-LD.
func (o OfficeHours) mergeOpts(objs ...interface{}) OfficeHours {
	// Start from current global state snapshot
	base := o
	for _, o := range objs {
		if v, ok := o.(OfficeHours); ok {
			if v.eventTitle != "" {
				base.eventTitle = v.eventTitle
			}
			if v.eventDescription != "" {
				base.eventDescription = v.eventDescription
			}
			if v.eventDayOfWeek != 0 {
				base.eventDayOfWeek = v.eventDayOfWeek
			}
			if v.eventStartHour != 0 {
				base.eventStartHour = v.eventStartHour
			}
			if v.eventDuration != 0 {
				base.eventDuration = v.eventDuration
			}
			if len(v.cancelledDates) > 0 {
				if base.cancelledDates == nil {
					base.cancelledDates = map[string]bool{}
				}
				for k, b := range v.cancelledDates {
					base.cancelledDates[k] = b
				}
			}
			if len(v.renderOpts) > 0 {
				if base.renderOpts == nil {
					base.renderOpts = map[string]any{}
				}
				for k, vv := range v.renderOpts {
					base.renderOpts[k] = vv
				}
			}
		}
	}
	return base
}

func (o OfficeHours) Compose(obj interface{}) eve.LogoGraph {
    return o.mergeOpts(obj)
}

// FromPath extracts overrides from the query string (?date=YYYY-MM-DD, etc.).
func (OfficeHours) FromPath(path string) interface{} {
	q := eve.ParseQuery(path)
	o := *officeHours // start from current
	if t := q.Get("title"); t != "" {
		o.eventTitle = t
	}
	if d := q.Get("description"); d != "" {
		o.eventDescription = d
	}
	if ds := q.Get("date"); ds != "" {
		// Allow one-off date: we’ll carry it through in Compose/Flyer via eventFromPath.
		// (No direct field; we read from path at build time.)
	}
	return o
}

// ToPath emits a stable query reflecting the current projection.
func (OfficeHours) ToPath(obj interface{}) string {
	o := OfficeHours{}.mergeOpts(obj)
	q := url.Values{}
	if o.eventTitle != "" {
		q.Set("title", o.eventTitle)
	}
	if o.eventDescription != "" {
		q.Set("description", o.eventDescription)
	}
	// You can add ?date=YYYY-MM-DD here if you’re pinning a specific session.
	return "?" + q.Encode()
}

// Compose builds the stable JSON-LD (and is what we CID over).
func (o OfficeHours) JsonLD() eve.JsonLDMap {

	// Build the concrete event for the current (or requested) session.
	// We intentionally don’t read path here to keep the LD stable; path-specific
	// choices (like ?date=) are “views.” If you want date-pinning in the CID,
	// pass an override object that sets it in your own workflow.
	evt := eventFromPath("") // next upcoming by default
	start := evt.StartDate
	end := evt.EndDate

	return eve.JsonLDMap{
		"@context":             "https://schema.org",
		"@type":                "ImageObject",
		"name":                 "Office Hours",
		"description":          o.eventDescription,
		"representativeOfPage": true,
		"url":                  std.CurrentRealm().PkgPath(),
		"about": map[string]interface{}{
			"@type":       "Event",
			"name":        o.eventTitle,
			"description": o.eventDescription,
			"eventStatus": string(evt.Status),
			"startDate":   start,
			"endDate":     end,
			"location": map[string]interface{}{
				"@type":   "Place",
				"name":    "Online",
				"address": "Online",
			},
		},
	}
}

// Flyer builds the eve.Flyer projection (used by SVG/Image).
func (OfficeHours) Flyer(obj ...interface{}) *eve.Flyer {
	// Build from the same concrete event we render elsewhere
	evt := eventFromPath("")
	f := &eve.Flyer{
		Name:      "Office Hours",
		Location:  &eve.Location{Name: "Online"},
		StartDate: evt.StartDate,
		EndDate:   evt.EndDate,
		Status:    eve.EventStatus(evt.Status),
		Sessions: []*eve.Session{
			{
				Title:       officeHours.eventTitle,
				Description: officeHours.eventDescription,
				StartTime:   evt.StartDate,
				EndTime:     evt.EndDate,
				Sequence:    officeHours.sequence,
			},
		},
		Images: []string{},
	}
	f.SetRenderOpts(officeHours.renderOpts)
	return f
}

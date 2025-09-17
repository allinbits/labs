package officehours

import (
	"std"
	"strings"

	"gno.land/p/demo/ufmt"
	"gno.land/p/demo/avl"
	eve "gno.land/p/eve000/event/component"
)

var calendarRegistry = avl.NewTree()

type Counter struct{ Count int64 }

func (c *Counter) Next() string { c.Count++; return c.String() }
func (c *Counter) String() string { return ufmt.Sprintf("%08d", c.Count) }

var counter = Counter{Count: 0}

// ---- Interfaces ----

type Editable interface {
	RenderForm(...string) string
}

type Projectable interface {
	ToPath(...interface{}) string
	FromPath(...string) interface{}
	Compose(...interface{}) interface{} // should return a value implementing LogoGraph
}

type LogoGraph interface {
	SVG(...string) string
	JsonLD(...string) eve.JsonLDMap
	Cid(...string) string
	Thumbnail(...string) string
}

// ---- Records ----

type Record struct {
	Name        string
	Description string
	Cid         string
	Object      interface{}
	Committer   string
	Seq         int64
}

// ---- Projection plumbing ----

// EmitProjectionEvent validates + emits, but does not register the projection.
func EmitProjectionEvent(base, path, seal string) (cid string) {
	return commitProjection(true, base, path, seal)
}

// CommitProjection validates + registers a projected object derived from base+path.
func CommitProjection(_ realm, base, path, seal string) (cid string) {
	return commitProjection(false, base, path, seal)
}

func commitProjection(emitOnly bool, base, path, seal string) (cid string) {
	if seal == "" {
		panic("seal parameter is required")
	}
	if !eve.IsCIDv1(base) {
		panic("invalid base: not a CIDv1")
	}
	if !eve.IsCIDv1(seal) {
		panic("invalid seal: not a CIDv1")
	}
	v, found := calendarRegistry.Get(base)
	if !found {
		return "base CID not found"
	}
	r := v.(Record)

	proj, isProj := r.Object.(Projectable)
	if !isProj {
		panic("object is not projectable")
	}

	// Build the projected object
	projected := proj.FromPath(path)
	// Compose to a LogoGraph (your Compose returns OhrScheduleObj, which implements LogoGraph)
	lg, ok := proj.Compose(projected).(LogoGraph)
	if !ok {
		panic("Compose(...) must return an object implementing LogoGraph")
	}
	cid = lg.JsonLD().Cid()

	if seal != cid {
		panic("invalid seal: expected " + cid + " but got " + seal)
	}
	if _, ok := calendarRegistry.Get(cid); ok {
		panic("duplicate projected CID registered: " + cid)
	}

	rec := Record{
		Name:        r.Name + " (projected)",
		Description: r.Description + " (projected)",
		Cid:         cid,
		Object:      projected,
		Committer:   std.PreviousRealm().Address().String(),
		Seq:         counter.Count + 1,
	}

	std.Emit("ProjectionEvent", "cid", cid, "seal", seal, "seq", counter.Next())
	if !emitOnly {
		calendarRegistry.Set(rec.Cid, rec)
	}
	return
}

// ---- Register ----

// Register adds a LogoGraph object to the calendarRegistry and returns its CID.
func Register(i interface{}, callback ...func(rec Record)) string {
	lg, ok := i.(LogoGraph)
	if !ok {
		panic("object must implement LogoGraph interface")
	}
	newCid := lg.Cid()
	if !eve.IsCIDv1(newCid) {
		panic("object must have a likely CIDv1 (base32, 'baf...' style)")
	}

	// Touch media to smoke-test
	_ = lg.SVG()
	_ = lg.Thumbnail()

	ld := lg.JsonLD()

	// Optional: enforce columns if you want strictness
	for _, col := range columns {
		if col == "cid" || col == "committer" {
			continue
		}
		if _, ok := ld[col]; !ok {
			panic("object must have " + col + " in its JSON-LD")
		}
	}

	rec := Record{
		Name:        ld.StringVal(columns[1]),
		Description: ld.StringVal(columns[2]),
		Cid:         newCid,
		Object:      i,
		Committer:   std.PreviousRealm().Address().String(),
		Seq:         counter.Count + 1,
	}
	if _, ok := calendarRegistry.Get(rec.Cid); ok {
		panic("duplicate CID registered: " + rec.Cid)
	}
	calendarRegistry.Set(rec.Cid, rec)
	std.Emit("Register", "cid", rec.Cid, "seq", counter.Next())
	for _, cb := range callback {
        cb(rec)
    }
	return newCid
}

var columns = []string{"cid", "name", "description", "committer"}

func (e Record) String() string {
	return "| [" + e.Cid[len(e.Cid)-8:] + "](?cid=" + e.Cid + ") | " + e.Name + " | " + e.Description + " | [" + e.Committer[len(e.Committer)-8:] + "](/u/" + e.Committer + ") |\n"
}

// ---- Render router ----

func Render(path string) string {
	q := eve.ParseQuery(path)

	cal, hasCal := q["cal"]
	if hasCal {
	    if calObj, ok := calendarRegistry.Get(cal[0]); ok {
            if rec, ok := calObj.(Record); ok {
                if c, ok := rec.Object.(calendar); ok {
                    if event, hasEvent := q["evt"]; hasEvent {
                        if evtObj, ok := c.Dates.Get(event[0]); ok {
                            return renderEvent(path, evtObj)
                        } else {
                            return "event cid not found: " + event[0]
                        }
                    }
                }
                return renderCalendar(path, rec.Object)
            } else {
                return "invalid calendar record"
            }
        } else {
            return "cal cid not found: " + cal[0]
        }
	}

	cid, hasCid := q["cid"]
	if !hasCid {
		if len(q["v"]) == 1 && q["v"][0] == "seq" {
			return counter.String()
		}
        return eventCalendar.RenderTable()
	}

	if submit, hasSubmit := q["submit"]; hasSubmit && submit[0] == "register" {
		if base, hasBase := q["base"]; hasBase && eve.IsCIDv1(base[0]) {
			if v, ok := calendarRegistry.Get(base[0]); ok {
				r := v.(Record)
				if ed, isEd := r.Object.(Editable); isEd {
					form := ed.RenderForm(path)
					if form != "" {
						return form
					}
				}
			} else {
				return "base cid not found: " + base[0]
			}
		} else {
			return "missing or invalid base parameter"
		}
	}

	v, found := calendarRegistry.Get(cid[0])
	if !found {
		return "cid not found"
	}

	r := v.(Record)
	obj := r.Object
	proj, isProj := r.Object.(Projectable)
	if isProj {
		obj = proj.FromPath(path)
	}

	if format, ok := q["v"]; ok {
		switch format[0] {
		case "ldjson":
			ld := obj.(LogoGraph).JsonLD()
			if ldjson, ok := q["ldjson"]; ok && len(ldjson) > 0 {
				parts := strings.Split(ldjson[0], ".")
				val := interface{}(ld)
				for _, p := range parts {
					if m, ok := val.(eve.JsonLDMap); ok {
						val = m[p]
					} else {
						return ""
					}
				}
				switch v := val.(type) {
				case string:
					return v
				default:
					return ufmt.Sprintf("%v", v)
				}
			}
			return ld.String()

		case "cid":
			if isProj {
				return "[" + proj.Compose(obj).(LogoGraph).JsonLD().Cid() + "](?cid=" + proj.Compose(obj).(LogoGraph).JsonLD().Cid() + ")"
			}
			return "[" + r.Cid + "](?cid=" + r.Cid + ")"

		case "seq":
			return ufmt.Sprintf("%d", r.Seq)

		case "committer":
			return r.Committer

		case "svg":
			return obj.(LogoGraph).SVG()

		case "thumbnail":
			return obj.(LogoGraph).Thumbnail()

		case "json":
			if isProj {
				return proj.Compose(obj).(LogoGraph).JsonLD().String()
			}
			return obj.(LogoGraph).JsonLD().String()
		}
	}

	// Optional seal verification
	if seal, ok := q["seal"]; ok && isProj {
		if !eve.IsCIDv1(seal[0]) {
			return "invalid seal: not a CIDv1"
		}
		calc := proj.Compose(obj).(LogoGraph).JsonLD().Cid()
		if seal[0] != calc {
			return "invalid seal: expected " + calc + " but got " + seal[0]
		}
	}

	return renderObject(path, obj)
}

func renderEvent(path string, obj interface{}) string {
    event, ok := obj.(Schedule)
    if !ok {
        return "object is not an event"
    }
    var sb strings.Builder
    sb.WriteString("### " + event.Title + "\n")
    sb.WriteString(event.Thumbnail() + "\n\n")
    sb.WriteString(event.Description + "\n\n")
    sb.WriteString("**Status:** " + event.Status + "\n\n")
    sb.WriteString("**Date:** " + event.StartDate[:10] + "\n\n")
    sb.WriteString("**Location:** " + event.Location + "\n\n")
    return sb.String()
}

func renderCalendar(path string, obj interface{}) string {
    calendar, ok := obj.(calendar)
    if !ok {
        return "object is not a calendar"
    }
    var sb strings.Builder
    sb.WriteString("### " + calendar.Title + "\n")
    sb.WriteString(calendar.Thumbnail() + "\n\n")
    // add a table of events
    sb.WriteString("| Date | Description |\n")
    sb.WriteString("| ---- | ----------- |\n")

    calendar.Dates.IterateByOffset(0,  calendar.Dates.Size(), func(_ string, value any) bool {
        evt := value.(Schedule)
        // REVIEW: consider using ?event={cid} for event links
        sb.WriteString("| " + evt.StartDate[:10] + " | [" + evt.Description + "](?evt=" + evt.Cid() + "&cal=" + calendar.Cid() + ") |\n")
        return false
    })

    return sb.String()
}

func renderObject(path string, obj interface{}) string {
	glyph := obj.(LogoGraph)

	var ld eve.JsonLDMap
	if proj, ok := obj.(Projectable); ok {
		ld = proj.Compose(proj.FromPath(path)).(LogoGraph).JsonLD()
	} else {
		ld = glyph.JsonLD()
	}

	var sb strings.Builder
	sb.WriteString("### " + ld.StringVal("name") + "\n")
	sb.WriteString(glyph.Thumbnail() + "\n\n")
	sb.WriteString(ld.StringVal("description") + "\n\n")

	sb.WriteString("#### CID\n")
	cid := ld.Cid()
	if proj, ok := obj.(Projectable); ok {
		if _, found := calendarRegistry.Get(cid); !found {
			sb.WriteString(cid + "\n\n")
			sb.WriteString(eve.Button("Commit Projection:    "+cid[len(cid)-8:], proj.ToPath(obj)+"&base="+glyph.Cid()+"&submit=register"+"\n"))
		} else {
			sb.WriteString("[" + cid + "](" + proj.ToPath(obj) + ")\n")
		}
	} else {
		sb.WriteString("[" + cid + "](?cid=" + cid + ")\n")
	}

	if links := ld.MarkdownLinks(); links != "" {
		sb.WriteString("\n### Links\n" + links + "\n")
	}

	sb.WriteString("\n#### JSON-LD\n```json\n" + strings.TrimSpace(ld.String()) + "\n```\n")
	return sb.String()
}
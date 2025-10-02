package component

import (
	ufmt "gno.land/p/demo/ufmt"
)

// -----------------------------------------------------------------------------
// Interfaces
// -----------------------------------------------------------------------------

type Editable interface {
	RenderForm(path string) string
}

type PageTemplate interface {
    Render(path string) string
}

type Projectable interface {
	ToPath(obj interface{}) string
	FromPath(path string) interface{}
	// Compose must return a value that implements LogoGraph.
	Compose(obj interface{}) LogoGraph
}

type LogoGraph interface {
	SVG() string
	JsonLD() JsonLDMap
	Cid() string
	Thumbnail() string
}

// -----------------------------------------------------------------------------
// Records
// -----------------------------------------------------------------------------

type Record struct {
	Name        string
	Description string
	Cid         string
	Object      interface{}
	Committer   string
	Seq         int64
}

func (e Record) String() string {
	return "| [" + Tail(e.Cid, 8) + "](?cid=" + e.Cid + ") | " +
		e.Name + " | " + e.Description + " | " +
		"[" + Tail(e.Committer, 8) + "](/u/" + e.Committer + ") |\n"
}

type Counter struct{ Count int64 }

func (c *Counter) Bump() int64    { c.Count++; return c.Count }
func (c *Counter) String() string { return ufmt.Sprintf("%08d", c.Count) }

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Resolve an arbitrary object (possibly projectable) into a LogoGraph view.
func AsLogoGraph(baseObj interface{}, path string) (lg LogoGraph, projected interface{}, ok bool) {
	switch v := baseObj.(type) {
	case Projectable:
		projected = v.FromPath(path)
		return v.Compose(projected), projected, true
	case LogoGraph:
		return v, v, true
	default:
		return nil, nil, false
	}
}

// Tail returns the last n characters of s (or the whole string if shorter).
func Tail(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[len(s)-n:]
}

// AssertProjectionRoundTrip verifies that for a Projectable object `obj`,
// the round-trip ToPath(obj) -> FromPath(path) -> (Compose if needed) yields
// a LogoGraph with the SAME CID as `lg` (the canonical view of obj).
//
// Panics with descriptive messages on violation.
func AssertProjectionRoundTrip(obj interface{}, lg LogoGraph) {
	proj, ok := obj.(Projectable)
	if !ok {
		// Not projectable → nothing to assert for this law.
		return
	}

	path := proj.ToPath(obj)
	fromObj := proj.FromPath(path)
	if fromObj == nil {
		panic("ProjectionRoundTrip: FromPath returned nil")
	}

	// If FromPath returned a LogoGraph directly, use it; otherwise Compose.
	var fromLG LogoGraph
	if v, ok := fromObj.(LogoGraph); ok {
		fromLG = v
	} else {
		fromLG = proj.Compose(fromObj)
		if fromLG == nil {
			panic("ProjectionRoundTrip: Compose(fromObj) returned nil LogoGraph")
		}
	}

	got := fromLG.Cid()
	want := lg.Cid()
	if got != want {
		panic("ProjectionRoundTrip: CID mismatch: " + got + " != " + want)
	}
}

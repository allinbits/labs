// ln -s ~/w/aib/eve/projects/gnoland/gno.land/p/eve000 eve
// gno test (maek sure you are eve-symlink branch)
package register

import (
	"testing"

	"gno.land/p/eve000/event"
	"gno.land/p/eve000/event/location"
	"gno.land/p/eve000/event/session"
	"gno.land/p/eve000/event/speaker"
)

func TestRegistry(t *testing.T) {
	registry := NewRegistry()

	// Create test data
	spkr := &speaker.Speaker{Name: "Alice"}
	loc := &location.Location{Name: "Main Hall"}
	sess := &session.Session{Speaker: spkr, Location: loc}
	evt := &event.Event{Name: "Annual Meeting", Sessions: []*session.Session{sess}}

	// Test RegisterEvent
	eventID := registry.RegisterEvent(evt)
	if eventID != 0 {
		t.Fatalf("expected event ID 0, got %d", eventID)
	}

	// Test GetEvent
	gotEvent := registry.GetEvent(eventID)
	if gotEvent.Name != evt.Name {
		t.Fatalf("expected event name %q, got %q", evt.Name, gotEvent.Name)
	}

	// Test GetSpeaker
	gotSpeaker := registry.GetSpeaker(0)
	if gotSpeaker.Name != spkr.Name {
		t.Fatalf("expected speaker name %q, got %q", spkr.Name, gotSpeaker.Name)
	}

	// Test GetLocation
	gotLocation := registry.GetLocation(0)
	if gotLocation.Name != loc.Name {
		t.Fatalf("expected location name %q, got %q", loc.Name, gotLocation.Name)
	}

	// Test GetSession by ID
	gotSession := registry.GetSession(0)
	if gotSession.Speaker.Name != spkr.Name || gotSession.Location.Name != loc.Name {
		t.Fatalf("expected session with speaker %q and location %q, got speaker %q and location %q",
			spkr.Name, loc.Name, gotSession.Speaker.Name, gotSession.Location.Name)
	}

	// Test GetEventSession
	gotEventSession := registry.GetEventSession(eventID, 0)
	if gotEventSession != sess {
		t.Fatalf("expected event session to match original session")
	}
}

func TestAddIndividualRecords(t *testing.T) {
	registry := NewRegistry()

	// Add and retrieve speaker
	spkrID := registry.AddSpeaker(&speaker.Speaker{Name: "Bob"})
	gotSpeaker := registry.GetSpeaker(spkrID)
	if gotSpeaker.Name != "Bob" {
		t.Fatalf("expected speaker name 'Bob', got %q", gotSpeaker.Name)
	}

	// Add and retrieve location
	locID := registry.AddLocation(&location.Location{Name: "Conference Room"})
	gotLocation := registry.GetLocation(locID)
	if gotLocation.Name != "Conference Room" {
		t.Fatalf("expected location name 'Conference Room', got %q", gotLocation.Name)
	}

	// Add and retrieve session
	sessID := registry.AddSession(&session.Session{
		Speaker:  &speaker.Speaker{Name: "Carol"},
		Location: &location.Location{Name: "Auditorium"},
	})
	gotSession := registry.GetSession(sessID)
	if gotSession.Speaker.Name != "Carol" || gotSession.Location.Name != "Auditorium" {
		t.Fatalf("expected session with speaker 'Carol' and location 'Auditorium', got speaker %q and location %q",
			gotSession.Speaker.Name, gotSession.Location.Name)
	}
}

func TestEdgeCases(t *testing.T) {
	registry := NewRegistry()

	// Panic if GetEventSession is out of bounds
	defer func() {
		if r := recover(); r == nil {
			t.Fatalf("expected panic for invalid session index in GetEventSession")
		}
	}()
	// Add one event with no sessions to trigger panic
	registry.RegisterEvent(&event.Event{Name: "Empty Event", Sessions: []*session.Session{}})
	registry.GetEventSession(0, 0) // invalid session index
}

func TestInvalidIDPanic(t *testing.T) {
	registry := NewRegistry()

	expectPanic := func(name string, f func()) {
		defer func() {
			if r := recover(); r == nil {
				t.Fatalf("expected panic in %s for invalid ID", name)
			}
		}()
		f()
	}

	expectPanic("GetSpeaker", func() { registry.GetSpeaker(999) })
	expectPanic("GetLocation", func() { registry.GetLocation(999) })
	expectPanic("GetEvent", func() { registry.GetEvent(999) })
	expectPanic("GetSession", func() { registry.GetSession(999) })
}

func TestAvlKeyFormat(t *testing.T) {
	key := event.AvlKey("speaker", 42)
	expected := "speaker:42"
	if string(key) != expected {
		t.Fatalf("expected AvlKey to be %q, got %q", expected, key)
	}
}

package metamodel

import mm "gno.land/p/metamodel000"

func init() {
	// REVIEW: consider writing an analysis on "The effectiveness of NES controller button mashing" for a specific game
	// model := combo([]string{"up", "up", "down", "down", "left", "right", "b", "a", "select", "start"})
	// model := combo([]string{"up", "down", "a"}) // Example combo: "up", "down", "a"
	// FIXME: this doesn't render legibly in the current Petri net viewer
	// register("NESControllerCombo", func(_ string) string {
	//     return model.ToMarkdown()
	// })
}

func pos(x, y int) struct{ X, Y int } {
	return struct{ X, Y int }{X: x * 80, Y: y * 80}
}

func gamepad() (map[string]mm.Place, map[string]mm.Transition, []mm.Arrow) {
	btn := "button"
	places := map[string]mm.Place{}
	transitions := map[string]mm.Transition{}
	arrows := []mm.Arrow{}

	controls := []struct {
		name string
		x, y int
	}{
		{"up", 2, 1},
		{"down", 2, 3},
		{"left", 1, 2},
		{"right", 3, 2},
		{"select", 4, 2},
		{"start", 5, 2},
		{"b", 6, 2},
		{"a", 7, 2},
	}

	for _, control := range controls {
		pos := pos(control.x, control.y)
		places[control.name] = mm.Place{X: pos.X, Y: pos.Y}
		transitions[control.name] = mm.Transition{Label: control.name, Offset: 0, X: pos.X, Y: pos.Y}
		arrows = append(arrows, mm.Arrow{
			Source: btn,
			Target: control.name,
			Weight: mm.T(1),
		})
	}

	return places, transitions, arrows
}

// Generate a Petri net model for a combo of commands
func combo(ngram []string) *mm.Model {
	offsetX := 4
	offsetY := 4

	places, transitions, arrows := gamepad()

	origin := mm.Place{X: pos(4, 1).X, Y: pos(4, 1).Y}
	places["origin"] = origin

	// Convert ngram slice to a map for fast lookups
	ngramSet := make(map[string]struct{}, len(ngram))
	for _, cmd := range ngram {
		ngramSet[cmd] = struct{}{}
	}

	for i := 0; i < len(ngram)-1; i++ {
		first := ngram[i]
		next := ngram[i+1]

		andThen := mm.Place{
			X: pos(offsetX+i, offsetY).X,
			Y: pos(offsetX+i, offsetY).Y,
		}
		places[first+".then."+next] = andThen

		arrows = append(arrows, mm.Arrow{
			Source: first,
			Target: first + ".then." + next,
			Weight: mm.T(1),
		}, mm.Arrow{
			Source: first + ".then." + next,
			Target: next,
			Weight: mm.T(1),
		})
	}

	noop := mm.Place{X: pos(5, 1).X, Y: pos(5, 1).Y}
	places["noop"] = noop

	for cmd := range transitions {
		if _, exists := ngramSet[cmd]; !exists {
			arrows = append(arrows, mm.Arrow{
				Source: "noop",
				Target: cmd,
				Weight: mm.T(1),
			})
		}
	}

	return &mm.Model{
		Places:      places,
		Transitions: transitions,
		Arrows:      arrows,
	}
}

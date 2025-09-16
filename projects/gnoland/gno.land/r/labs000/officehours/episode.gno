package officehours

import (
	eve "gno.land/p/eve000/event/component"
)

type episode struct {
    title string
}

var evt = episode{}

//var cid = Register(evt)
var cid string = "bafybeihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku" // TODO: replace with real cid

var titles = []string{
    "Episode 1: Introduction to Gno.land",
    "Episode 2: Building Smart Contracts",
    "Episode 3: Understanding Gno Modules",
    "Episode 4: Deploying on Gno.land",
    "Episode 5: Advanced Gno Programming",
}

func (episode) Event() OfficeHoursEvent {
    // TODO: can we get this from
	return OfficeHoursEvent{
		Status:      "EventPlanned",
		StartDate:   "2025-11-01T00:00:00Z",
		EndDate:     "2025-11-01T01:00:00Z",
		Description: "Part 1" + " of " + evt.title,
		Location:    "Gnowhere",
	}
}

func (episode) Cid() string {
	return OfficeHours.Compose(evt.Event()).Cid()
}

func (episode) Image() string {
	return OfficeHours.Image()
}

func (episode) DataUrl() string {
	return OfficeHours.DataUrl()
}

func (episode) Thumbnail() string {
    // REVIEW: thumbnail should be the SVG version of the flyer
	return OfficeHours.Thumbnail()
}

func (episode) SVG() string {
	return OfficeHours.SVG()
}

func (episode) JsonLD() eve.JsonLDMap {
	return OfficeHours.Compose(evt.Event())
}

/*
func (episode) FromPath(path string) interface{} {
	return OfficeHours.FromPath(path)
}

func (episode) ToPath(obj ...interface{}) string {
	return OfficeHours.ToPath(obj...)
}

func (episode) Compose(obj ...interface{}) eve.JsonLDMap {
	return OfficeHours.Compose(ev
}

*/
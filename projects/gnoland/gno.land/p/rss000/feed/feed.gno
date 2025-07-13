package feed

import (
	"strings"
	"time"
)

// Feed represents the main feed structure.
type Feed struct {
	Title       string
	Link        *Link
	Description string
	Author      *Author
	PubDate     time.Time
}

// Link represents a hyperlink with an Href attribute.
type Link struct {
	Href string
}

// Author represents the author of the feed or an item.
type Author struct {
	Name  string
	Email string
}

// Item represents an individual feed item.
type Item struct {
	Title       string
	Link        *Link
	Description string
	Content     string // Optional content for the item
	PubDate     time.Time
}

func RssTime(t time.Time) string {
	return t.Format("02 Jan 2006 15:04 -0700")
}

func (item *Item) ToJson() string {
	return `{
    "title": "` + item.Title + `",
    "link": "` + item.Link.Href + `",
    "description": "` + item.Description + `",
    "content": "` + item.Content + `",
    "guid": "` + item.Link.Href + `",
    "pubData": "` + RssTime(item.PubDate) + `"
}`
}

func itemsToJson(items []*Item) string {
	var jsonItems []string
	for _, item := range items {
		jsonItems = append(jsonItems, item.ToJson())
	}
	return strings.Join(jsonItems, ", ")
}

func (f *Feed) ToJson(items []*Item) string {
	return `{
        "title": "` + f.Title + `",
        "link": "` + f.Link.Href + `",
        "description": "` + f.Description + `",
        "created": "` + RssTime(f.PubDate) + `",
        "items": [` + itemsToJson(items) + `]
    }`
}

package logoverse

type FeedItem struct {
	CID     string   // optional: CIDv1 (base32) of this glyph instance
	Parents []string // optional: parent CIDs (structured lineage); empty means root
	Commit  string   // optional: link to the commit/revision object/id
	Url     string   // canonical or viewer URL for the projection
}

func NewFeedItem(owner string) FeedItem {
	return FeedItem{
		Url: "https://gno.land/r/labs000/logoverse/feed.gno?cid={{CID}}",
	}
}

// WithCID sets the glyph CID.
func (d FeedItem) WithCID(cid string) FeedItem { d.CID = cid; return d }

// WithParents sets parent lineage.
func (d FeedItem) WithParents(parents ...string) FeedItem {
	d.Parents = append([]string{}, parents...)
	return d
}

// WithCommit sets the commit/revision pointer.
func (d FeedItem) WithCommit(commit string) FeedItem { d.Commit = commit; return d }

func (d FeedItem) JsonLD() map[string]interface{} {
	// Logoverse context fragment describing our custom terms.

	// Single glyph node (projectable).
	glyph := map[string]interface{}{
		"@type": "Item",
		// Optional fields only included when set (keeps the JSON stable for CID calculation).
		// You can omit @id until you’ve computed the CID over the canonical JSON.
	}
	if d.CID != "" {
		glyph["@id"] = d.CID
	}
	if len(d.Parents) > 0 {
		glyph["parents"] = d.Parents
	}
	if d.Commit != "" {
		glyph["commit"] = d.Commit
	}

	// schema.org fields (stable and human-facing)
	glyph["url"] = d.Url
	glyph["name"] = "Feed"
	glyph["description"] = "Feed is a public protocol for publishing messages onchain. It is designed to be simple, durable, and open to extension by anyone."

	// Emit a proper LogoGraph wrapper with @graph.
	return map[string]interface{}{
		"@context": []interface{}{"https://schema.org", LogoverseContext},
		"@graph":   []interface{}{glyph},

		// Optional top-level labels (helpful for UIs; not required for CID if you exclude them when hashing)
		"name":        "Feed",
		"description": "LogoGraph: Feed glyph (projectable) using Logoverse vocabulary.",
	}
}

package metamodel

import (
	"net/url"
	"sort"
	"strconv"
	"strings"
	"time"

	"std"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
	"gno.land/p/rss000/feed"
)

// FIXME: this isn't pure anymore since we link to metamodel000 directly.

type RegistryCallback = func(key string, value interface{}) bool
type RegistryMatcher = func(value interface{}) bool

type Record struct {
	Id       int
	Title    string
	Content  interface{}
	Keywords []string
}

func (record Record) String() string {
	var sb strings.Builder
	sb.WriteString("Record{Content: ")
	if record.Content != nil {
		sb.WriteString("interface{}")
	} else {
		sb.WriteString("nil")
	}
	sb.WriteString(", Keywords: [")
	for i, keyword := range record.Keywords {
		if i > 0 {
			sb.WriteString(", ")
		}
		sb.WriteString(keyword)
	}
	sb.WriteString("]}")
	return sb.String()
}

type Registry struct {
	tree          *avl.Tree
	allowPrefixes []string
	renderOpts    map[string]interface{}
	keywordIndex  *avl.Tree // maps keyword -> []string (keys)
}

func NewRegistry(allowedPrefixes []string, renderOpts map[string]interface{}) *Registry {
	return &Registry{
		tree:          avl.NewTree(),
		allowPrefixes: allowedPrefixes,
		renderOpts:    renderOpts,
		keywordIndex:  avl.NewTree(),
	}
}

// --- Registration & Access Control ---

func (r *Registry) Register(key string, obj interface{}, kw ...string) {
	r.assertAccess()
	r.register(key, obj, kw...)
}

func (r *Registry) register(name string, obj interface{}, kw ...string) {
	key := sanitizeAnchorKey(name)
	if r.Exists(key) {
		panic("Key already exists: " + key)
	}
	kw = append(kw, name)
	kwords := keywords(kw)
	switch obj := obj.(type) {
	case *Model:
		r.tree.Set(key, Record{
			Id:       r.tree.Size(),
			Title:    name,
			Content:  func(...interface{}) *Model { return obj },
			Keywords: kwords,
		})
		for _, word := range kwords {
			val, _ := r.keywordIndex.Get(word)
			var keys []string
			if val != nil {
				keys = val.([]string)
			}
			keys = append(keys, key)
			r.keywordIndex.Set(word, keys)
		}
	default:
		panic(ufmt.Sprintf("Invalid type for key %s: %T", key, obj))
	}
}

func (r *Registry) Exists(key string) bool {
	_, ok := r.tree.Get(key)
	return ok
}

func (r *Registry) assertAccess() {
	if !r.hasAllowedPrefix() {
		panic("access denied: " + std.PreviousRealm().PkgPath() +
			" realm must match an allowed prefix:[" + strings.Join(r.allowPrefixes, ",") + "]")
	}
}

func (r *Registry) hasAllowedPrefix() bool {
	prevRealm := std.PreviousRealm()
	for _, callerPath := range r.allowPrefixes {
		if strings.HasPrefix(prevRealm.PkgPath(), callerPath) {
			return true
		}
	}
	return false
}

// --- Query & Indexing ---

func (r *Registry) KeysByKeyword(word string) []string {
	val, ok := r.keywordIndex.Get(strings.ToLower(word))
	if !ok {
		return nil
	}
	return val.([]string)
}

func (r *Registry) Iterate(callback RegistryCallback, matcher RegistryMatcher) {
	r.tree.IterateByOffset(0, r.tree.Size(), func(key string, value interface{}) bool {
		if matcher(value) {
			return callback(key, value)
		}
		return false
	})
}

// --- Rendering & Content ---

func (r *Registry) Render(path string) string {
	if strings.HasPrefix(path, "?") {
        q := parseQuery(path)
        if idx, ok := q["i"]; ok && len(idx) > 0 {
            return r.renderItem(idx[0], q)
        }
    } else {
        key := sanitizeAnchorKey(path)
        if _, ok := r.tree.Get(key); ok {
            return r.Content(key, path)
        }
         if c, ok := r.keywordIndex.Get(strings.ToLower(key)); ok {
             var sb strings.Builder
                sb.WriteString("## Search Results for: " + key + "\n\n")
                sb.WriteString("Found " + ufmt.Sprintf("%d", len(c.([]string))) + " results:\n\n")
            for _, k := range c.([]string) {
                obj, ok := r.tree.Get(k)
                if !ok {
                    continue
                }
                rec := obj.(Record)
                sb.WriteString("### [" + upcaseWords(rec.Title) + "](/r/metamodel000?i=" + k + ")\n")
                sb.WriteString("**Keywords:** " + strings.Join(rec.Keywords, ", ") + "\n\n")
                sb.WriteString(r.thumbnail(k, obj) + "\n")
            }
            sb.WriteString("\n[<- Home](/r/metamodel000)\n")
            return sb.String()
         }
    }
	return r.renderIndex(path)
}

func (r *Registry) renderItem(indexStr string, u url.Values) string {
	index, _ := strconv.Atoi(indexStr)
	i := index % r.tree.Size()
	key, obj := r.tree.GetByIndex(i)
	rec := obj.(Record)
	var sb strings.Builder
	sb.WriteString("### " + upcaseWords(rec.Title) + "\n\n")
	sb.WriteString("**[" + key + "🔗](/r/metamodel000:" + key + ")**\n\n")
	sb.WriteString("**Keywords:** " + strings.Join(rec.Keywords, ", ") + "\n\n") // TODO: make links
	sb.WriteString(r.renderNavigation(i, u))
	sb.WriteString(r.Content(key, ""))
	sb.WriteString(r.renderNavigation(i, u))
	sb.WriteString("**Keywords:** " + strings.Join(rec.Keywords, ", ") + "\n\n")
	sb.WriteString("\n[<- Home](/r/metamodel000)")

	return sb.String()
}

func (r *Registry) renderNavigation(i int, u url.Values) string {
	var sb strings.Builder
	prev := (i - 1 + r.tree.Size()) % r.tree.Size()
	next := (i + 1) % r.tree.Size()
	sb.WriteString("[<-prev](?i=" + ufmt.Sprintf("%d", prev) + ") ")
	sb.WriteString(ufmt.Sprintf("%d/%d", i, r.tree.Size()-1))
	sb.WriteString(" [next->](?i=" + ufmt.Sprintf("%d", next) + ")\n\n")
	return sb.String()
}

func (r *Registry) renderIndex(path string) string {
	q := parseQuery(path)
	if page, ok := q["p"]; ok && len(page) > 0 {
		return r.renderList(path)
	}
	return "## Models\n\n" +
		"This is a public registry of metamodels.\n\n" +
		"TODO: You can view the RSS Feed for updates.\n\n" +
		"[Metamodel Index ->](/r/metamodel000?p=0)\n\n" +
		r.TagCloudMarkdown() + "\n\n" +
		"[Metamodel Index ->](/r/metamodel000?p=0)\n\n"
}

func (r *Registry) renderList(path string) string {
	const pageSize = 5
	var sb strings.Builder
	total := r.tree.Size()
	page := 0
	if u := parseQuery(path); u != nil {
		if idx, ok := u["p"]; ok && len(idx) > 0 {
			if i, err := strconv.Atoi(idx[0]); err == nil {
				page = i
			}
		}
	}
	start := page * pageSize
	end := start + pageSize
	if end > total {
		end = total
	}
	for i := start; i < end; i++ {
		key, obj := r.tree.GetByIndex(i)
		sb.WriteString("### [" + upcaseWords(key) + "](?i=" + ufmt.Sprintf("%d", i) + ")\n")
		sb.WriteString(r.thumbnail(key, obj))
	}
	var nav strings.Builder
	if total > pageSize {
		nav.WriteString("\n")
		if page > 0 {
			nav.WriteString("[Prev Page](?p=" + ufmt.Sprintf("%d", page-1) + ") ")
		}
		nav.WriteString(ufmt.Sprintf("Page %d/%d", page+1, (total+pageSize-1)/pageSize))
		if end < total {
			nav.WriteString(" [Next Page](?p=" + ufmt.Sprintf("%d", page+1) + ")")
		}
		nav.WriteString("\n")
	}
	sb.WriteString(nav.String())
	return "## Metamodel Index\n\n" +
		nav.String() +
		sb.String() +
		"\n[<- Home](/r/metamodel000)\n"
}

func (r *Registry) Content(key, path string) string {
	key = sanitizeAnchorKey(key)
	val, ok := r.tree.Get(key)
	if !ok {
		panic("Key not found: " + key)
	}
	rec := val.(Record)
	model := rec.Content.(func(...interface{}) *Model)()
	if binding, ok := model.Binding.(func(path string) string); ok {
		return binding(path)
	}
	return model.ToMarkdown()
}

func (r *Registry) Preview(key, path string) string {
	key = sanitizeAnchorKey(key)
	val, ok := r.tree.Get(key)
	if !ok {
		panic("Key not found: " + key)
	}
	rec := val.(Record)
	model := rec.Content.(func(...interface{}) *Model)()
	lineCount := 3
	var content string
	if binding, ok := model.Binding.(func(string) string); ok {
		content = binding(path)
		lines := strings.Split(content, "\n")
		if len(lines) > lineCount {
			return strings.Join(lines[:lineCount], "\n") + "\n"
		}
	} else {
		content = model.ToMarkdown()
	}
	return markdownPreview(content)
}

func (r *Registry) thumbnail(key string, obj interface{}) string {
	rec := obj.(Record)
	var sb strings.Builder
	sb.WriteString("**Keywords:** " + strings.Join(rec.Keywords, ", ") + "\n\n")
	model := rec.Content.(func(...interface{}) *Model)()
	sb.WriteString("![" + key + "](" + model.ThumbnailDataUrl() + ")\n")
	sb.WriteString(r.Preview(key, "") + "\n")
	return sb.String()
}

// --- Tag Cloud & RSS ---

func (r *Registry) TagCloudMarkdown() string {
	tagCounts := r.TagCloud()
	var tags []string
	for tag := range tagCounts {
		tags = append(tags, tag)
	}
	sort.Strings(tags)
	var sb strings.Builder
	sb.WriteString("### Index Keywords\n\n")
	for _, tag := range tags {
		sb.WriteString("- " + tag + " (" + strconv.Itoa(tagCounts[tag]) + ")\n")
	}
	return sb.String()
}

func (r *Registry) TagCloud() map[string]int {
	tagCounts := make(map[string]int)
	r.tree.IterateByOffset(0, r.tree.Size(), func(_ string, value interface{}) bool {
		rec := value.(Record)
		for _, kw := range rec.Keywords {
			tagCounts[kw]++
		}
		return false
	})
	return tagCounts
}

func (r *Registry) getItems() []*feed.Item {
	var items []*feed.Item
	host := r.renderOpts["host"].(string)
	r.Iterate(func(key string, value interface{}) bool {
		if _, ok := value.(*Model); ok {
			items = append(items, &feed.Item{
				Title:       key,
				Link:        &feed.Link{Href: host + "r/metamodel000:" + key},
				Description: "",
				Content:     "",
				PubDate:     time.Now(),
			})
		} else {
			panic("registry value is not an Item: " + key)
		}
		return false
	}, HasModelApi)
	return items
}

// --- Helpers ---

func keywords(kw []string) (out []string) {
	for _, k := range kw {
		multiWords := strings.Split(k, " ")
		for _, word := range multiWords {
			if len(word) == 0 {
				continue
			}
			out = append(out, strings.ToLower(word))
		}
	}
	return out
}

func parseQuery(path string) url.Values {
	if len(path) > 0 && path[0] == '?' {
		u, err := url.Parse(std.CurrentRealm().PkgPath() + path)
		if err == nil {
			return u.Query()
		}
	}
	return url.Values{}
}

func upcaseWords(s string) string {
	words := strings.Fields(s)
	for i, word := range words {
		if len(word) > 0 {
			words[i] = strings.ToUpper(string(word[0])) + word[1:]
		}
	}
	return strings.Join(words, " ")
}

func markdownPreview(content string) string {
	regexImages := `!\[.*?\]\(.*?\)`
	content = strings.ReplaceAll(content, regexImages, "")
	return content
}

// Add this helper function
func sanitizeAnchorKey(key string) string {
	key = strings.ToLower(key)
	key = strings.ReplaceAll(key, " ", "-")
	// Remove all non-alphanumeric and non-hyphen characters
	var sb strings.Builder
	for _, r := range key {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == '-' {
			sb.WriteRune(r)
		}
	}
	return sb.String()
}

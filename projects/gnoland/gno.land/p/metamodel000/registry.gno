package metamodel

import (
	"net/url"
	"std"
	"strconv"
	"strings"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
	"gno.land/p/rss000/feed"
)

type ContentBlock = func(path string) string
type RegistryCallback = func(key string, value interface{}) bool
type RegistryMatcher = func(value interface{}) bool

type Registry struct {
	tree          *avl.Tree
	allowPrefixes []string
	renderOpts    map[string]interface{}
}

func NewRegistry(allowedPrefixes []string, renderOpts map[string]interface{}) *Registry {
	return &Registry{
		tree:          avl.NewTree(),
		allowPrefixes: allowedPrefixes,
		renderOpts:    renderOpts,
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

func (r *Registry) assertAccess() {
	if !r.hasAllowedPrefix() {
		panic("access denied: " + std.PreviousRealm().PkgPath() +
			" realm must match an allowed prefix:[" + strings.Join(r.allowPrefixes, ",") + "]")
	}
}

func (r *Registry) Register(key string, obj interface{}) {
	r.assertAccess()
	r.register(key, obj)
}

func (r *Registry) register(key string, obj interface{}) {
	switch obj := obj.(type) {
	case ContentBlock:
		r.tree.Set(key, obj)
	case *Model:
		r.tree.Set(key, ModelFactory(func(_ ...interface{}) *Model {
			return obj
		}))
	case ModelFunc:
		r.tree.Set(key, ModelFactory(func(_ ...interface{}) *Model {
			return obj()
		}))
	case ModelFactory:
		r.tree.Set(key, obj)
	default:
		panic(ufmt.Sprintf("Invalid type for key %s: %T", key, obj))
	}
}

func (r *Registry) Preview(key, path string) string {
	obj, ok := r.tree.Get(key)
	if !ok {
		panic("Key not found: " + key)
	}

	lineCount := 3

	switch obj := obj.(type) {
	case ContentBlock:
		content := obj(path)
		lines := strings.Split(content, "\n")
		if len(lines) > lineCount {
			return strings.Join(lines[:lineCount], "\n") + "\n"
		}
		return content
	case ModelFactory:
		model := obj()
		if binding, ok := model.Binding.(ContentBlock); ok {
			content := binding(path)
			lines := strings.Split(content, "\n")
			if len(lines) > lineCount {
				return strings.Join(lines[:lineCount], "\n") + "\n"
			}
			return content
		}
		return model.ToMarkdown()
	default:
		panic("Key is not a ContentBlock or ModelFactory: " + key)
	}
}

func (r *Registry) Content(key, path string) string {
	obj, ok := r.tree.Get(key)
	if !ok {
		panic("Key not found: " + key)
	}

	switch obj := obj.(type) {
	case ContentBlock:
		return obj(path)
	case ModelFactory:
		model := obj()
		if binding, ok := model.Binding.(ContentBlock); ok {
			return binding(path)
		}
		return model.ToMarkdown()
	default:
		panic("Key is not a ContentBlock or ModelFactory: " + key)
	}
}

func (r *Registry) Model(key string, inputs ...interface{}) *Model {
	factory, ok := r.tree.Get(key)
	if !ok {
		panic("Key not found: " + key)
	}

	if modelFactory, ok := factory.(ModelFactory); ok {
		return modelFactory(inputs...)
	}
	panic("Key is not a ModelFactory: " + key)
}

func (r *Registry) Iterate(callback RegistryCallback, matcher RegistryMatcher) {
	r.tree.IterateByOffset(0, r.tree.Size(), func(key string, value interface{}) bool {
		if matcher(value) {
			return callback(key, value)
		}
		return false
	})
}

// TODO: test + use this w/ a feed
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

func (r *Registry) Render(path string) string {
	u := parseQuery(path)
	if idx, ok := u["i"]; ok && len(idx) > 0 {
		return r.renderItem(idx[0], u)
	}
	return r.renderIndex()
}

func (r *Registry) renderItem(indexStr string, u url.Values) string {
	index, _ := strconv.Atoi(indexStr)
	i := index % r.tree.Size()
	key, _ := r.tree.GetByIndex(i)

	var sb strings.Builder
	sb.WriteString("### " + upcaseWords(key) + "\n\n")
	sb.WriteString(r.renderNavigation(i, u))
	sb.WriteString(r.Content(key, ""))
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

func (r *Registry) thumbnail(key string, obj interface{}) string {
	switch obj := obj.(type) {
	case ModelFactory:
		model := obj()
		return "![" + key + "](" + model.ThumbnailDataUrl() + ")\n" +
			r.Preview(key, "") + "\n"
	case ContentBlock:
		return "[no thumbnail]\n"
	default:
		return "[default]\n"
	}
}

func (r *Registry) renderIndex() string {
	var sb strings.Builder
	sb.WriteString("### Metamodel Index\n\n")
	sb.WriteString("This is the index of the metamodel. " +
		"You can use the `?i=` query parameter to navigate through the models.\n\n")
	sb.WriteString("Available models:\n\n")

	for i := 0; i < r.tree.Size(); i++ {
		key, obj := r.tree.GetByIndex(i)
		sb.WriteString("- [" + upcaseWords(key) + "](?i=" + ufmt.Sprintf("%d", i) + ")\n")
		sb.WriteString(r.thumbnail(key, obj))
	}
	return sb.String()
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

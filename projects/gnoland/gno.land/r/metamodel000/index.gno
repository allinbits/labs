package metamodel

import (
	"net/url"
	"std"
	"strconv"
	"strings"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
	mm "gno.land/p/metamodel000"
	"gno.land/p/rss000/feed"
)

var (
	registry         = avl.NewTree()
	realmAllowPrefix = []string{}
	displayPaths     = []string{}
	renderOpts       = map[string]interface{}{
		"host": "http://",
	}
)

func init() {
	realmAllowPrefix = append(realmAllowPrefix, std.CurrentRealm().PkgPath()+"/")
}

type ContentBlock = func(path string) string

func hasAllowedPrefix() bool {
	prevRealm := std.PreviousRealm()
	for _, callerPath := range realmAllowPrefix {
		if strings.HasPrefix(prevRealm.PkgPath(), callerPath) {
			return true
		}
	}
	return false
}

func assertAccess() {
	if !hasAllowedPrefix() {
		panic("access denied: " + std.PreviousRealm().PkgPath() +
			" realm must match an allowed prefix:[" + strings.Join(realmAllowPrefix, ",") + "]")
	}
}

func Register(cur realm, key string, obj interface{}) {
	assertAccess()
	register(key, obj)
}

func register(key string, obj interface{}) {
	switch obj := obj.(type) {
	case ContentBlock:
		registry.Set(key, obj)
	case *mm.Model:
		registry.Set(key, mm.ModelFactory(func(_ ...interface{}) *mm.Model {
			return obj
		}))
	case mm.ModelFunc:
		registry.Set(key, mm.ModelFactory(func(_ ...interface{}) *mm.Model {
			return obj()
		}))
	case mm.ModelFactory:
		registry.Set(key, obj)
	default:
		panic(ufmt.Sprintf("Invalid type for key %s: %T", key, obj))
	}
	displayPaths = append(displayPaths, key)
}

func Content(key, path string) string {
	obj, ok := registry.Get(key)
	if !ok {
		panic("Key not found: " + key)
	}

	switch obj := obj.(type) {
	case ContentBlock:
		return obj(path)
	case mm.ModelFactory:
		model := obj()
		if binding, ok := model.Binding.(ContentBlock); ok {
			return binding(path)
		}
		return model.ToMarkdown()
	default:
		panic("Key is not a ContentBlock or ModelFactory: " + key)
	}
}

func Model(key string, inputs ...interface{}) *mm.Model {
	factory, ok := registry.Get(key)
	if !ok {
		panic("Key not found: " + key)
	}

	if modelFactory, ok := factory.(mm.ModelFactory); ok {
		return modelFactory(inputs...)
	}
	panic("Key is not a ModelFactory: " + key)
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

type RegistryCallback = func(key string, value interface{}) bool
type RegistryMatcher = func(value interface{}) bool

func IterateRegistry(callback RegistryCallback, matcher RegistryMatcher) {
	registry.IterateByOffset(0, registry.Size(), func(key string, value interface{}) bool {
		if matcher(value) {
			return callback(key, value)
		}
		return false
	})
}

func getItems() []*feed.Item {
	var items []*feed.Item
	host := renderOpts["host"].(string)

	IterateRegistry(func(key string, value interface{}) bool {
		if _, ok := value.(*mm.Model); ok {
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
	}, mm.HasModelApi)

	return items
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

func Render(path string) string {
	u := parseQuery(path)
	if idx, ok := u["i"]; ok && len(idx) > 0 {
		return renderItem(idx[0], u)
	}
	return renderIndex()
}

func renderItem(indexStr string, u url.Values) string {
	index, _ := strconv.Atoi(indexStr)
	i := index % registry.Size()
	key, _ := registry.GetByIndex(i)

	var sb strings.Builder
	sb.WriteString("### " + upcaseWords(key) + "\n\n")
	sb.WriteString(renderNavigation(i, u))
	sb.WriteString(Content(key, ""))
	return sb.String()
}

func renderNavigation(i int, u url.Values) string {
	var sb strings.Builder
	prev := (i - 1 + registry.Size()) % registry.Size()
	next := (i + 1) % registry.Size()

	sb.WriteString("[<-prev](?i=" + ufmt.Sprintf("%d", prev) + ") ")
	sb.WriteString(ufmt.Sprintf("%d/%d", i, registry.Size()-1))
	sb.WriteString(" [next->](?i=" + ufmt.Sprintf("%d", next) + ")\n\n")
	return sb.String()
}

func thumbnail(key string, obj interface{}) string {
	switch obj := obj.(type) {
	case mm.ModelFactory:
		model := obj() // Call the ModelFactory function
		return "![" + key + "](" + model.ThumbnailDataUrl() + ")\n"
	case ContentBlock:
		return "[no thumbnail]\n"
	default:
		// If the object does not have a thumbnail, return an empty string.
		return "[default]\n"
	}
}

func renderIndex() string {
	var sb strings.Builder
	sb.WriteString("### Metamodel Index\n\n")
	sb.WriteString("This is the index of the metamodel. " +
		"You can use the `?i=` query parameter to navigate through the models.\n\n")
	sb.WriteString("Available models:\n\n")

	for i := 0; i < registry.Size(); i++ {
		key, obj := registry.GetByIndex(i)
		sb.WriteString("- [" + upcaseWords(key) + "](?i=" + ufmt.Sprintf("%d", i) + ")\n")
		sb.WriteString("  - [Link to model](./metamodel000:" + key + ")\n")
		sb.WriteString(thumbnail(key, obj))
	}
	return sb.String()
}

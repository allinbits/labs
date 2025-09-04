package logoverse

import (
	"net/url"
)
/*
TODO: consider adding JSON-LD output
{
  "@context": {
    "$object": "https://schema.org/Thing",
    "$token": "https://schema.org/Product",
    "$glyph": "https://schema.org/ImageObject"
  }
}
*/

type Registry map[string]Term

type Term struct {
    Word string
    Binding func(string) string
}

var registry = Registry{
	"$logoverse": Term{
		Word:    "logoverse",
		Binding: logoverseDef,
	},
}

func Render(path string) string {
    q := QueryValues(path)
    if term, ok := registry[q.Get("term")]; ok {
        return term.Binding(path)
    }
    return registry["$logoverse"].Binding(path)
}


func QueryValues(fullURL string) url.Values {
	u, err := url.Parse(fullURL)
	if err != nil {
		panic("Error Parsing URL")
	}
	return u.Query()
}

func term(s string) string {
    return "[" + s + "](?term=" + s + ")"
}

func dataURL(svg string) string {
	return "data:image/svg+xml;utf8," + url.PathEscape(svg)
}
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

func QueryValues(fullURL string) url.Values {
	u, err := url.Parse(fullURL)
	if err != nil {
		panic("Error Parsing URL")
	}
	return u.Query()
}

func Render(path string) string {
    q := QueryValues(path)
    if term, ok := registry[q.Get("term")]; ok {
        return term.Binding(path)
    }
    return registry["$logoverse"].Binding(path)
}


func term(s string) string {
    return "[" + s + "](?term=" + s + ")"
}

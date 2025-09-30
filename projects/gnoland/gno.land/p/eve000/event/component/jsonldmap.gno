package component

import (
	"strings"

	"gno.land/p/demo/ufmt"
)

type JsonLDMap map[string]interface{}

func (ld JsonLDMap) String() string {
	s := "{\n"
	i := 0
	n := len(ld)
	for k, v := range ld {
		s += `  "` + k + `": ` + toJSONString(v)
		if i < n-1 {
			s += ",\n"
		} else {
			s += "\n"
		}
		i++
	}
	s += "}"
	return s
}

func (ld JsonLDMap) Cid() string {
	return ShaToCid(HashString(ld.String()))
}

func (ld JsonLDMap) StringVal(key string) string {
	if v, ok := ld[key]; ok {
		return v.(string)
	}
	return ""
}

// FIXME: nested types get string encoded - see aiblabes .about

func toJSONString(v interface{}) string {
	switch val := v.(type) {
	case string:
		return `"` + val + `"`
	case float64, float32, int, int64, int32, bool:
		return ufmt.Sprintf("%v", val)
	case JsonLDMap:
		return val.String()
	case map[string]interface{}:
		return JsonLDMap(val).String()
	case []interface{}:
		s := "["
		for i, elem := range val {
			if i > 0 {
				s += ", "
			}
			s += toJSONString(elem)
		}
		s += "]"
		return s
	case []string:
		s := "["
		for i, elem := range val {
			if i > 0 {
				s += ", "
			}
			s += `"` + elem + `"`
		}
		s += "]"
		return s
	default:
		return `"` + ufmt.Sprintf("%v", val) + `"`
	}
}

func (ld JsonLDMap) MarkdownLinks() string {
	var collectUrls func(interface{}, string, map[string]string)
	collectUrls = func(v interface{}, path string, urls map[string]string) {
		switch val := v.(type) {
		case map[string]interface{}:
			for k, v2 := range val {
				newPath := k
				if path != "" {
					newPath = path + "." + k
				}
				if k == "url" {
					if urlStr, ok := v2.(string); ok {
						urls[newPath] = "[" + urlStr + "](" + urlStr + ")"
					}
				} else if k == "license" {
					if licStr, ok := v2.(string); ok && (strings.HasPrefix(licStr, "http://") || strings.HasPrefix(licStr, "https://")) {
						urls[newPath] = "[" + licStr + "](" + licStr + ")"
					}
				} else if k == "thumbnail" {
					if licStr, ok := v2.(string); ok && (strings.HasPrefix(licStr, "/r/") || strings.HasPrefix(licStr, "https://")) {
						urls[newPath] = "[" + licStr + "](" + licStr + ")"
					}
				} else if k == "banner" {
					if licStr, ok := v2.(string); ok && (strings.HasPrefix(licStr, "/r/") || strings.HasPrefix(licStr, "https://")) {
						urls[newPath] = "[" + licStr + "](" + licStr + ")"
					}
				} else if (k == "parentId" || k == "seal") {
					if str, ok := v2.(string); ok && str != "" {
					    if IsCIDv1(str) {
                            urls[newPath] = "[" + str + "](?cid=" + str + ")"
                        }
					}
				} else {
					collectUrls(v2, newPath, urls)
				}
			}
		case JsonLDMap:
			collectUrls(map[string]interface{}(val), path, urls)
		case []interface{}:
			for i, elem := range val {
				idxPath := path + "[" + ufmt.Sprintf("%d", i) + "]"
				collectUrls(elem, idxPath, urls)
			}
		}
	}
	urls := make(map[string]string)
	collectUrls(ld, "", urls)
	table := "| Key | Value |\n| --- | ----- |\n"
	for k, v := range urls {
		table += "| " + k + " | " + v + " |\n"
	}
	return table
}

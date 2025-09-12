package component

import (
    "gno.land/p/demo/ufmt"
)

type JsonLDMap map[string]interface{}

func (ld JsonLDMap) String() string {
	s := "{\n"
	for k, v := range ld {
		s += `  "` + k + `": ` + toJSONString(v) + ",\n"
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

 // toJSONString recursively converts values to JSON-like strings.
func toJSONString(v interface{}) string {
	switch val := v.(type) {
	case string:
		return `"` + val + `"`
	case float64, float32, int, int64, int32, bool:
		return ufmt.Sprintf("%v", val)
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
	default:
		return `"` + ufmt.Sprintf("%v", val) + `"`
	}
}


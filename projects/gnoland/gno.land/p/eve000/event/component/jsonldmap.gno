package component

import (
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
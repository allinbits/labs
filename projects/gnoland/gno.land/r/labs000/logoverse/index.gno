package logoverse

import (
    eve "gno.land/p/eve000/event/component"
    "gno.land/p/demo/ufmt"
)

var cb = `
#### Welcome to a "**small 'L' logoverse**"
This is an index of immutable objects found in this realm.
`
// TODO: add registry index by CID - we can hash JSON-LD to get a CIDv1

type Logo interface {
    SVG() string
    JsonLD() JsonLDMap
    Cid() string
}

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
    return eve.ShaToCid(eve.HashString(ld.String()))
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

func Render(_ string) string {
	return cb + " \n## pflow.xyz \n" + Pflow.Image() +
	    "\n```\n\n" + Pflow.JsonLD().String() + "\n\n```\n" +
		"\n\n---\n\n" +
		"## aiblabs.net \n" + AibLabs.Image() +
		"\n```\n\n" + AibLabs.JsonLD().String() + "\n\n```\n" +
		"\n\n---\n\n" +
		"## allinbits.com \n" + AllInBits.Image() +
		"\n```\n\n" + AllInBits.JsonLD().String() + "\n\n```\n" +
		"\n\n---\n\n" +
		"## $photon \n" + Photon.ThumbnailImage() +
		"\n```\n\n" + Photon.JsonLD().String() + "\n\n```\n" +
		"\n\n---\n\n" +
		"## $atone \n" + Atone.ThumbnailImage() +
		"\n```\n\n" + Atone.JsonLD().String() + "\n\n```\n" +
		"\n\n---\n\n" +
		"## Event \n" + Event.Thumbnail() +
		"\n```\n\n" + Event.JsonLD().String() + "\n\n```\n"
}

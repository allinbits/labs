package metamodel

import (
    "strings"
)

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

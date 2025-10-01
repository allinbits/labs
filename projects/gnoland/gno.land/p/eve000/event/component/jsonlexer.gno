package component

import (
	"unicode"
	"strings"
)

func IsValidJson(input string) bool {
	i := 0
	n := len(input)
	var stack []rune

	skipWhitespace := func() {
		for i < n && unicode.IsSpace(rune(input[i])) {
			i++
		}
	}

	match := func(s string) bool {
		if strings.HasPrefix(input[i:], s) {
			i += len(s)
			return true
		}
		return false
	}

	parseString := func() bool {
		if i >= n || input[i] != '"' {
			return false
		}
		i++
		for i < n {
			if input[i] == '"' {
				i++
				return true
			}
			if input[i] == '\\' {
				i++
				if i >= n {
					return false
				}
			}
			i++
		}
		return false
	}

	parseNumber := func() bool {
		start := i
		if i < n && (input[i] == '-' || input[i] == '+') {
			i++
		}
		digits := 0
		for i < n && unicode.IsDigit(rune(input[i])) {
			i++
			digits++
		}
		if digits == 0 {
			return false
		}
		if i < n && input[i] == '.' {
			i++
			digits = 0
			for i < n && unicode.IsDigit(rune(input[i])) {
				i++
				digits++
			}
			if digits == 0 {
				return false
			}
		}
		if i < n && (input[i] == 'e' || input[i] == 'E') {
			i++
			if i < n && (input[i] == '-' || input[i] == '+') {
				i++
			}
			digits = 0
			for i < n && unicode.IsDigit(rune(input[i])) {
				i++
				digits++
			}
			if digits == 0 {
				return false
			}
		}
		return i > start
	}

	var parseValue func() bool
	parseValue = func() bool {
		skipWhitespace()
		switch {
		case i < n && input[i] == '{':
			stack = append(stack, '{')
			i++
			skipWhitespace()
			if i < n && input[i] == '}' {
				stack = stack[:len(stack)-1]
				i++
				return true
			}
			for {
				skipWhitespace()
				if !parseString() {
					return false
				}
				skipWhitespace()
				if i >= n || input[i] != ':' {
					return false
				}
				i++
				if !parseValue() {
					return false
				}
				skipWhitespace()
				if i < n && input[i] == '}' {
					stack = stack[:len(stack)-1]
					i++
					return true
				}
				if i < n && input[i] == ',' {
					i++
					continue
				}
				return false
			}
		case i < n && input[i] == '[':
			stack = append(stack, '[')
			i++
			skipWhitespace()
			if i < n && input[i] == ']' {
				stack = stack[:len(stack)-1]
				i++
				return true
			}
			for {
				if !parseValue() {
					return false
				}
				skipWhitespace()
				if i < n && input[i] == ']' {
					stack = stack[:len(stack)-1]
					i++
					return true
				}
				if i < n && input[i] == ',' {
					i++
					continue
				}
				return false
			}
		case i < n && input[i] == '"':
			return parseString()
		case i < n && (unicode.IsDigit(rune(input[i])) || input[i] == '-' || input[i] == '+'):
			return parseNumber()
		case match("true"), match("false"), match("null"):
			return true
		default:
			return false
		}
	}

	skipWhitespace()
	if !parseValue() {
		return false
	}
	skipWhitespace()
	return i == n && len(stack) == 0
}
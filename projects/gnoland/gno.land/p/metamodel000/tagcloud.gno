package metamodel

import (
	"net/url"
	"sort"
	"strconv"
	"strings"
)

func (r *Registry) TagCloudMarkdown() string {
	tagCounts := r.TagCloud()
	var tags []string
	for tag := range tagCounts {
		tags = append(tags, tag)
	}
	sort.Strings(tags)
	var sb strings.Builder
	sb.WriteString("### Keyword Index\n\n")
	var lastInitial rune
	for _, tag := range tags {
		initial := []rune(tag)[0]
		if initial != lastInitial {
			sb.WriteString("\n#### ")
			sb.WriteString(strings.ToUpper(string(initial)))
			sb.WriteString("\n")
			lastInitial = initial
		}
		sb.WriteString("- [")
		sb.WriteString(tag)
		sb.WriteString("](/r/metamodel000:" + tag + ") (" + strconv.Itoa(tagCounts[tag]) + ")\n")
	}
	return sb.String()
}

func (r *Registry) TagCloud() map[string]int {
	tagCounts := make(map[string]int)
	r.tree.IterateByOffset(0, r.tree.Size(), func(_ string, value any) bool {
		rec := value.(Record)
		for _, kw := range rec.Keywords {
			tagCounts[kw]++
		}
		return false
	})
	return tagCounts
}

func (r *Registry) TagCloudDataUrl() string {
	svg := r.TagCloudSVG()
	return "data:image/svg+xml;utf8," + url.PathEscape(svg)
}

func (r *Registry) TagCloudSVG() string {
	tagCounts := r.TagCloud()
	tags := getSortedTags(tagCounts)
	minCount, maxCount := getMinMaxCounts(tagCounts)
	if minCount == maxCount {
		minCount = 1 // avoid division by zero
	}
	svgWidth := 800
	svgHeight := 500
	html := buildTagCloudHTML(tags, tagCounts, minCount, maxCount)
	return embedHTMLInSVG(html, svgWidth, svgHeight)
}

func getSortedTags(tagCounts map[string]int) []string {
	var tags []string
	for tag := range tagCounts {
		tags = append(tags, tag)
	}
	sort.Strings(tags)
	return tags
}

func getMinMaxCounts(tagCounts map[string]int) (int, int) {
	minCount, maxCount := 1<<31-1, 0
	for _, count := range tagCounts {
		if count < minCount {
			minCount = count
		}
		if count > maxCount {
			maxCount = count
		}
	}
	return minCount, maxCount
}

func buildTagCloudHTML(tags []string, tagCounts map[string]int, minCount, maxCount int) string {
	const colWidth = 300
	const maxY = 480
	y := 40
	col := 0

	var htmlSb strings.Builder
	htmlSb.WriteString(`<div style="font-family: Arial, sans-serif;">`)
	for _, tag := range tags {
		count := tagCounts[tag]
		scale := calculateScale(count, minCount, maxCount)
		fontSize := 1.0 + 0.1*float64(scale)
		color := calculateTagColor(count, minCount, maxCount)

		htmlSb.WriteString(buildTagSpan(tag, fontSize, color))
		y += 20 + scale*2
		if y > maxY {
			y = 40
			col++
			htmlSb.WriteString("<br/>")
		}
	}
	htmlSb.WriteString(`</div>`)
	return htmlSb.String()
}

func calculateScale(count, minCount, maxCount int) int {
	scale := 1
	if maxCount > minCount {
		scale = 1 + int(float64(count-minCount)*19/float64(maxCount-minCount))
	}
	if scale < 1 {
		scale = 1
	}
	if scale > 20 {
		scale = 20
	}
	return scale
}

func calculateTagColor(count, minCount, maxCount int) string {
	t := 0.0
	if maxCount > minCount {
		t = float64(count-minCount) / float64(maxCount-minCount)
	}
	rCol := int(51 + t*153)
	gCol := int(102 - t*51)
	bCol := int(204 - t*153)
	return "#" + strconv.FormatInt(int64(rCol), 16) +
		strconv.FormatInt(int64(gCol), 16) +
		strconv.FormatInt(int64(bCol), 16)
}

func buildTagSpan(tag string, fontSize float64, color string) string {
	var sb strings.Builder
	sb.WriteString(`<span style="display:inline-block;margin:4px;font-size:`)
	sb.WriteString(strconv.FormatFloat(fontSize, 'f', 1, 64))
	sb.WriteString(`em;color:`)
	sb.WriteString(color)
	sb.WriteString(`;">`)
	sb.WriteString(tag)
	sb.WriteString(`</span>`)
	return sb.String()
}

func embedHTMLInSVG(html string, svgWidth, svgHeight int) string {
	var sb strings.Builder
	sb.WriteString(`<svg xmlns="http://www.w3.org/2000/svg" width="`)
	sb.WriteString(strconv.Itoa(svgWidth))
	sb.WriteString(`" height="`)
	sb.WriteString(strconv.Itoa(svgHeight))
	sb.WriteString(`">`)
	sb.WriteString(`<foreignObject x="0" y="0" width="100%" height="100%">`)
	sb.WriteString(`<body xmlns="http://www.w3.org/1999/xhtml">`)
	sb.WriteString(html)
	sb.WriteString(`</body></foreignObject></svg>`)
	return sb.String()
}

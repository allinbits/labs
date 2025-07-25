package gno_cdn

import (
	"encoding/json"
	"fmt"
	"github.com/go-chi/chi/v5"
	"net/http"
	"text/template"
)

type Badge struct {
	Realm          string                 `json:"realm"`
	StructuredData map[string]interface{} `json:"meta,omitempty"` // Optional metadata for the badge
	Meta           string                 `json:"-"`
}

const svgTemplate = `<svg xmlns="http://www.w3.org/2000/svg" width="400" height="50">
<title>Visit realm /r/{{.Realm}}</title>
{{.Meta}}
<style>
 .badge-text {
  font-family: Arial, sans-serif;
  font-size: 16px;
  fill: #000;
  text-anchor: middle;
  text-decoration: underline;
}
</style>
 <text class="badge-text" x="80" y="28" fill="#fff" font-size="16" font-family="Arial, sans-serif">/r/{{.Realm}}</text>
 <g transform="translate(8, 5)">
  <svg width="34" height="34" viewBox="0 0 34 34" fill="none" xmlns="http://www.w3.org/2000/svg">
   <path d="M24.3981 21.4357C24.3981 21.4353 24.3981 21.435 24.398 21.4346C24.2011 20.7261 23.7808 20.1025 23.2105 19.6262C22.9904 19.4419 22.7502 19.2674 22.4878 19.1049C22.2654 18.9665 21.9852 19.1704 22.0497 19.4212L22.2076 20.034C22.4077 20.8125 21.556 21.4439 20.8465 21.0437L18.9395 19.9685C17.6864 19.262 16.1452 19.262 14.892 19.9685L12.985 21.0437C12.2756 21.4439 11.4239 20.8114 11.624 20.034L11.7864 19.4037C11.8509 19.154 11.5718 18.9501 11.3494 19.0875C11.058 19.2663 10.7934 19.4604 10.5532 19.6643C9.99168 20.1419 9.60138 20.7831 9.41902 21.4897L9.41235 21.5158C8.94867 23.3216 9.66921 25.22 11.2237 26.2897L16.0385 29.6013C16.5655 29.9633 17.2672 29.9633 17.7942 29.6013L22.609 26.2897C24.1867 25.2048 24.905 23.2652 24.3982 21.4368C24.3982 21.4364 24.3981 21.4361 24.3981 21.4357V21.4357Z" fill="#999999"/>
   <path d="M24.1944 17.4535C23.9204 15.2083 23.0928 12.9603 22.0882 10.935C21.1893 9.12255 21.4167 6.906 22.8612 5.48951V5.48951C23.4216 4.93994 23.0246 4 22.2318 4H16.9011C16.4897 4 16.0772 4.17774 15.7992 4.53212C13.9222 6.92776 10.2472 12.1988 9.60562 17.4535C9.5478 17.9322 10.1205 18.2255 10.4874 17.905C11.7684 16.7862 13.7665 15.9858 16.9 15.9858C20.0335 15.9858 22.0306 16.7873 23.3126 17.905C23.6796 18.2255 24.2522 17.9311 24.1944 17.4535Z" fill="#226C57"/>
  </svg>
 </g>
</svg>`

// WriteSvg writes the badge as an SVG to the HTTP response.
func (badge *Badge) WriteSvg(w http.ResponseWriter) error {
	if badge == nil {
		return fmt.Errorf("badge is nil")
	}
	if badge.Realm == "" {
		return fmt.Errorf("realm is empty")
	}

	w.Header().Set("Content-Type", "image/svg+xml")

	// Parse the SVG template
	tmpl, err := template.New("badge").Parse(svgTemplate)
	if err != nil {
		return fmt.Errorf("error parsing SVG template: %w", err)
	}

	// Execute the template
	if err := tmpl.Execute(w, badge); err != nil {
		return fmt.Errorf("error executing SVG template: %w", err)
	}

	return nil
}

// handleBadge handles HTTP requests for rendering badges.
func (s *Server) handleBadge(w http.ResponseWriter, r *http.Request) {
	realm := chi.URLParam(r, "*")
	if realm == "" {
		http.Error(w, "Missing realm path", http.StatusBadRequest)
		return
	}

	// TODO: validate that realm is a valid Gno realm
	// REVIEW: consider gathering additional metadata author and on-chain data

	badge := &Badge{
		Realm: realm,
	}

	badge.StructuredData = map[string]interface{}{
		"@context":    "https://schema.org",
		"@type":       "CreativeWork", // REVIEW: https://schema.org/CreativeWork
		"accessMode":  []string{"textual"},
		"name":        "Gno Realm",
		"description": fmt.Sprintf("Gno.land realm %s", realm),
		"url":         fmt.Sprintf("https://gno.land/r/%s", realm),
	}

	jsonLd, _ := json.Marshal(badge.StructuredData)
	badge.Meta = "<script type=\"application/ld+json\">" + string(jsonLd) + "</script>"

	if err := badge.WriteSvg(w); err != nil {
		http.Error(w, "Error writing badge: "+err.Error(), http.StatusInternalServerError)
	}
}

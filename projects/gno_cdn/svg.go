package gno_cdn

import (
	"fmt"
	"github.com/go-chi/chi/v5"
	"golang.org/x/exp/slog"
	"net/http"
)

// RenderSvg calls the RenderSvg function on the target realm and returns the SVG content.
func (s *Server) RenderSvg(path string) (string, error) {
	realm := "gno.land/r/" + path
	slog.Info("Rendering SVG for realm", slog.String("realm", realm))

	// TODO: pass along url path parameters to the RenderSvg function if needed

	stringToken, _, err := s.gnoClient.QEval(realm, fmt.Sprintf(`RenderSvg("")`))
	if err != nil {
		slog.Error("Error evaluating QEval", slog.String("realm", realm), slog.String("err", err.Error()))
		return "", fmt.Errorf("QEval error: %w", err)
	}

	stringToken = stringToken[2 : len(stringToken)-9] // Remove leading '(' and trailing 'string)'
	svg := unescape(stringToken)                      // Remove escape sequences

	// TODO: validate that svg is a valid SVG document - may also choose to exclude scripts etc...

	return svg, nil
}

// handleSvg handles HTTP requests for rendering SVG.
func (s *Server) handleSvg(w http.ResponseWriter, r *http.Request) {
	realm := chi.URLParam(r, "*")
	if realm == "" {
		http.Error(w, "Missing realm path", http.StatusBadRequest)
		return
	}

	svgContent, err := s.RenderSvg(realm)
	if err != nil {
		http.Error(w, "Error rendering SVG: "+err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "image/svg+xml")
	if _, err := w.Write([]byte(svgContent)); err != nil {
		http.Error(w, "Error writing SVG response: "+err.Error(), http.StatusInternalServerError)
	}
}

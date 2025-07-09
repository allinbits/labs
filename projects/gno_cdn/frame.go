package gno_cdn

import (
	"encoding/json"
	"fmt"
	"github.com/go-chi/chi/v5"
	"golang.org/x/exp/slog"
	"net/http"
	"net/url"
	"strconv"
)

// unescape processes escape sequences in a string.
func unescape(s string) string {
	var result string
	for i := 0; i < len(s); {
		ch := s[i]
		if ch == '\\' && i+1 < len(s) {
			next := s[i+1]
			switch next {
			case 'n':
				result += "\n"
				i += 2
			case '"':
				result += "\""
				i += 2
			case '\\':
				result += "\\"
				i += 2
			default:
				result += string(ch)
				i++
			}
		} else {
			result += string(ch)
			i++
		}
	}
	return result
}

// Frame represents a data structure for rendering frames.
type Frame struct {
	Gnomark string                 `json:"gnomark"`
	Cdn     map[string]interface{} `json:"cdn"`
	Data    map[string]interface{} `json:"-"`
}

func (frame *Frame) WriteHtml(w http.ResponseWriter) error {
	if frame == nil {
		return fmt.Errorf("frame is nil")
	}
	if frame.Gnomark == "" {
		return fmt.Errorf("gnomark is empty")
	}

	w.Header().Set("Content-Type", "text/html")
	data, _ := json.MarshalIndent(frame.Data, "", "  ")
	head := ""

	var cdn *url.URL
	staticCdn, ok := frame.Cdn["static"]
	if ok {
		cdn, _ = url.Parse(staticCdn.(string))
		head = fmt.Sprintf("<head><script src=\"%sgnomark/frame/frame.js\"></script>\n</head>", cdn.Path)
	}
	htmlData := fmt.Sprintf(`<!DOCTYPE html>
<html lang="en">
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
%s
<title>GnoMark Frame</title>
<pre>
%s</pre>
<script>`, head, data)

	if _, err := w.Write([]byte(htmlData)); err != nil {
		return fmt.Errorf("error writing response: %w", err)
	}
	return nil
}

// WriteJson writes the frame data to the HTTP response.
func (frame *Frame) WriteJson(w http.ResponseWriter) error {
	if frame == nil {
		return fmt.Errorf("frame is nil")
	}
	if frame.Gnomark == "" {
		return fmt.Errorf("gnomark is empty")
	}

	w.Header().Set("Content-Type", "application/json")
	jsonData, err := json.MarshalIndent(frame.Data, "", "  ")
	if err != nil {
		return fmt.Errorf("error marshalling frame data: %w", err)
	}
	if _, err = w.Write(jsonData); err != nil {
		return fmt.Errorf("error writing response: %w", err)
	}
	return nil
}

// getFrameFromRequest extracts and processes a frame from the HTTP request.
func (s *Server) getFrameFromRequest(r *http.Request) (*Frame, error) {
	realm := chi.URLParam(r, "*")
	if realm == "" {
		return nil, fmt.Errorf("missing realm path")
	}

	realm = "gno.land/r/" + realm // Add prefix
	slog.Info("Rendering frame for realm", slog.String("realm", realm))

	path := strconv.Quote("?" + r.URL.RawQuery)
	stringToken, _, err := s.gnoClient.QEval(realm, fmt.Sprintf(`RenderFrame(%s)`, path))
	if err != nil {
		slog.Error("Error evaluating QEval", slog.String("realm", realm), slog.String("err", err.Error()))
		return nil, fmt.Errorf("QEval error: %w", err)
	}

	stringToken = stringToken[2 : len(stringToken)-9] // Remove leading '(' and trailing 'string)'
	stringToken = unescape(stringToken)               // Remove newlines and other whitespace

	var frame Frame
	if err = json.Unmarshal([]byte(stringToken), &frame); err != nil {
		slog.Error("Error unmarshalling frame", slog.String("realm", realm), slog.String("err", err.Error()))
		return nil, fmt.Errorf("unmarshal error: %w", err)
	}

	if frame.Gnomark == "" {
		slog.Error("Gnomark is empty", slog.String("realm", realm))
		return nil, fmt.Errorf("gnomark is empty for realm: %s", realm)
	}

	if err = json.Unmarshal([]byte(stringToken), &frame.Data); err != nil {
		slog.Error("Error unmarshalling frame data", slog.String("realm", realm), slog.String("err", err.Error()))
		return nil, fmt.Errorf("unmarshal error: %w", err)
	}

	slog.Info("Frame rendered successfully", slog.String("gnomark", frame.Gnomark), slog.String("realm", realm))
	return &frame, nil
}

// handleFrame handles HTTP requests for rendering frames.
func (s *Server) handleFrame(w http.ResponseWriter, r *http.Request) {
	frame, err := s.getFrameFromRequest(r)
	if err != nil {
		http.Error(w, "QEval error: "+err.Error(), http.StatusInternalServerError)
		return
	}

	if err = frame.WriteHtml(w); err != nil {
		http.Error(w, "Error writing frame: "+err.Error(), http.StatusInternalServerError)
	}
}

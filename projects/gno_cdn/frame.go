package gno_cdn

import (
	"encoding/json"
	"fmt"
	"github.com/go-chi/chi/v5"
	"golang.org/x/exp/slog"
	"net/http"
	"strconv"
)

func unescape(s string) string {
	result := ""
	i := 0
	for i < len(s) {
		ch := s[i]
		if ch == '\\' && i+1 < len(s) {
			next := s[i+1]
			if next == 'n' {
				result += "\n"
				i += 2
			} else if next == '"' {
				result += "\""
				i += 2
			} else if next == '\\' {
				result += "\\"
				i += 2
			} else {
				// unknown escape, copy literally
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

type Frame struct {
	Gnomark string                 `json:"gnomark"`
	Data    map[string]interface{} `json:"-"`
}

func (frame *Frame) Write(w http.ResponseWriter) error {
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
	_, err = w.Write(jsonData)
	if err != nil {
		return fmt.Errorf("error writing response: %w", err)
	}
	return nil
}

func (s *Server) getFrameFromRequest(r *http.Request) (*Frame, error) {
	var frame *Frame
	realm := chi.URLParam(r, "*")
	if realm == "" {
		return frame, fmt.Errorf("missing realm path")
	}

	realm = "gno.land/r/" + realm // add prefix

	slog.Info("Rendering frame for realm", slog.String("realm", realm))
	path := strconv.Quote("?" + r.URL.RawQuery)
	stringToken, _, err := s.gnoClient.QEval(realm, fmt.Sprintf(`RenderFrame(%s)`, path))
	if err != nil {
		slog.Error("Error evaluating QEval", slog.String("realm", realm), slog.String("err", err.Error()))
		return frame, fmt.Errorf("QEval error: %w", err)
	}
	stringToken = stringToken[2 : len(stringToken)-9] // Remove leading '(' and trailing 'string)'
	stringToken = unescape(stringToken)               // remove newlines and other whitespace

	err = json.Unmarshal([]byte(stringToken), &frame)
	if err != nil {
		slog.Error("Error unmarshalling frame", slog.String("realm", realm), slog.String("err", err.Error()))
		return frame, fmt.Errorf("unmarshal error: %w", err)
	}

	// Check if gnomark is empty
	if frame.Gnomark == "" {
		slog.Error("Gnomark is empty", slog.String("realm", realm))
		return frame, fmt.Errorf("gnomark is empty for realm: %s", realm)
	}

	err = json.Unmarshal([]byte(stringToken), &frame.Data)
	if err != nil {
		slog.Error("Error unmarshalling frame data", slog.String("realm", realm), slog.String("err", err.Error()))
		return frame, fmt.Errorf("unmarshal error: %w", err)
	}

	slog.Info("Frame rendered successfully", slog.String("gnomark", frame.Gnomark), slog.String("realm", realm))
	return frame, nil
}

func (s *Server) handleFrame(w http.ResponseWriter, r *http.Request) {
	// get the realm from the request
	frame, err := s.getFrameFromRequest(r)
	if err != nil {
		http.Error(w, "QEval error: "+err.Error(), http.StatusInternalServerError)
		return
	}

	err = frame.Write(w)
	if err != nil {
		http.Error(w, "Error writing frame: "+err.Error(), http.StatusInternalServerError)
		return
	}
}

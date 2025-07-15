package gnocal

// use chi v5 for server routing

import (
	"embed"
	"fmt"
	"html/template"
	"net/http"
	"strconv"
	"strings"

	"github.com/gnolang/gno/gno.land/pkg/gnoclient"
	rpcclient "github.com/gnolang/gno/tm2/pkg/bft/rpc/client"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

var f = fmt.Sprintf

//go:embed static/*
var static embed.FS

type Server struct {
	router    *chi.Mux
	gnoClient *gnoclient.Client
	config    *ServerOptions
}

type ServerOptions struct {
	GnolandRpcUrl string
	GnocalAddress string
}

func NewGnocalServer(config *ServerOptions) *Server {
	gnolandRpcClient, err := rpcclient.NewHTTPClient(config.GnolandRpcUrl)
	if err != nil {
		panic(f("Failed to create Gno client: %s", err.Error()))
	}

	s := &Server{
		router:    chi.NewRouter(),
		gnoClient: &gnoclient.Client{RPCClient: gnolandRpcClient},
		config:    config,
	}

	s.router.Use(middleware.Logger)
	s.router.Use(middleware.Recoverer)

	s.router.Handle("/static/*", http.StripPrefix("/static/", http.FileServer(http.Dir("static"))))

	s.router.Get("/", s.RenderLandingPage)
	s.router.Get("/*", s.RenderCalFromRealm)

	return s
}

func (s *Server) Run() error {
	return http.ListenAndServe(s.config.GnocalAddress, s.router)
}

func (s *Server) RenderCalFromRealm(w http.ResponseWriter, r *http.Request) {
	//gnocal.com/gno.land/r/buidlthefuture000/events/gnolandlaunch/calendar?format=ics
	//gnocal.com/gno.land/r/buidlthefuture000/events/gnolandlaunch/calendar
	calendarPath := chi.URLParam(r, "*")
	if calendarPath == "" {
		http.Error(w, "missing realm path", http.StatusBadRequest)
		return
	}

	path := strconv.Quote("?" + r.URL.RawQuery) // e.g. "?" + "apple=2&session=1&session=100&session=0&format=json"
	stringToken, _, err := s.gnoClient.QEval(calendarPath, f(`RenderCal(%s)`, path))
	if err != nil {
		w.Header().Set("Content-Type", "text/html")
		w.WriteHeader(http.StatusInternalServerError)

		errStr := err.Error()
		switch {

		case strings.Contains(errStr, "connect: connection refused"):
			tmpl, parseErr := template.ParseFS(static, "static/connection_refused.html")
			if parseErr != nil {
				http.Error(w, "Template error", http.StatusInternalServerError)
				return
			}
			tmpl.Execute(w, map[string]string{
				"RpcUrl": s.config.GnolandRpcUrl,
			})
			return

		case strings.Contains(errStr, "invalid package path"):
			tmpl, parseErr := template.ParseFS(static, "static/invalid_realm_path.html")
			if parseErr != nil {
				http.Error(w, "Template error", http.StatusInternalServerError)
				return
			}
			tmpl.Execute(w, map[string]string{
				"InputPath": calendarPath,
			})
			return

		case strings.Contains(errStr, "name RenderCal not declared"):
			if _, _, renderErr := s.gnoClient.QEval(calendarPath, `Render("")`); renderErr == nil {
				tmpl, parseErr := template.ParseFS(static, "static/rendercal_not_declared.html")
				if parseErr != nil {
					http.Error(w, "Template error", http.StatusInternalServerError)
					return
				}
				tmpl.Execute(w, map[string]string{
					"RealmPath": calendarPath,
				})
				return
			}
			tmpl, parseErr := template.ParseFS(static, "static/no_render_defined.html")
			if parseErr != nil {
				http.Error(w, "Template error", http.StatusInternalServerError)
				return
			}
			tmpl.Execute(w, nil)
			return

		default:
			tmpl, parseErr := template.ParseFS(static, "static/unknown_render_error.html")
			if parseErr != nil {
				http.Error(w, "Template error", http.StatusInternalServerError)
				return
			}
			tmpl.Execute(w, map[string]string{
				"InputPath":    calendarPath,
				"ErrorMessage": errStr,
			})
			return
		}
	}

	var out string // TODO: this is output post-processing, should be refactored out w/ better design
	if removedLParen, cutPrefix := strings.CutPrefix(stringToken, `("`); cutPrefix {
		out = removedLParen
	}
	if removedRParen, cutSuffix := strings.CutSuffix(out, `" string)`); cutSuffix {
		out = removedRParen
	}
	w.Header().Set("Content-Type", "text/calendar; charset=utf-8")
	w.Write([]byte(strings.ReplaceAll(out, `\n`, "\n")))
}

func (s *Server) RenderLandingPage(w http.ResponseWriter, r *http.Request) {
	content, err := static.ReadFile("static/landing_page.html")
	if err != nil {
		http.Error(w, "static/landing_page.html not found", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "text/html")
	w.WriteHeader(http.StatusOK)
	w.Write(content)
}

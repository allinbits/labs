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

// Templae pre-parsing
var (
	tmplConnectionRefused    = mustParseTemplate("connection_refused.html")
	tmplInvalidRealmPath     = mustParseTemplate("invalid_realm_path.html")
	tmplRenderCalNotDeclared = mustParseTemplate("rendercal_not_declared.html")
	tmplNoRenderDefined      = mustParseTemplate("no_render_defined.html")
	tmplUnknownRenderError   = mustParseTemplate("unknown_render_error.html")
	tmplLandingPage          = mustParseTemplate("landing_page.html")
)

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
	calendarPath := chi.URLParam(r, "*")
	if calendarPath == "" {
		http.Error(w, "missing realm path", http.StatusBadRequest)
		return
	}

	path := strconv.Quote("?" + r.URL.RawQuery)
	stringToken, _, err := s.gnoClient.QEval(calendarPath, f(`RenderCal(%s)`, path))
	if err != nil {
		w.Header().Set("Content-Type", "text/html")
		w.WriteHeader(http.StatusInternalServerError)

		errStr := err.Error()
		switch {
		case strings.Contains(errStr, "connect: connection refused"):
			tmplConnectionRefused.Execute(w, map[string]string{
				"RpcUrl": s.config.GnolandRpcUrl,
			})
		case strings.Contains(errStr, "invalid package path"):
			tmplInvalidRealmPath.Execute(w, map[string]string{
				"InputPath": calendarPath,
			})
		case strings.Contains(errStr, "name RenderCal not declared"):
			if _, _, renderErr := s.gnoClient.QEval(calendarPath, `Render("")`); renderErr == nil {
				tmplRenderCalNotDeclared.Execute(w, map[string]string{
					"RealmPath": calendarPath,
				})
			} else {
				tmplNoRenderDefined.Execute(w, nil)
			}
		default:
			tmplUnknownRenderError.Execute(w, map[string]string{
				"InputPath":    calendarPath,
				"ErrorMessage": errStr,
			})
		}
		return
	}

	var out string
	if removedLParen, cutPrefix := strings.CutPrefix(stringToken, `("`); cutPrefix {
		out = removedLParen
	}
	if removedRParen, cutSuffix := strings.CutSuffix(out, `" string)`); cutSuffix {
		out = removedRParen
	}

	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.Header().Set("Content-Disposition", "inline; filename=calendar.ics")
	w.Write([]byte(strings.ReplaceAll(out, `\n`, "\n")))
}

func (s *Server) RenderLandingPage(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html")
	w.WriteHeader(http.StatusOK)
	tmplLandingPage.Execute(w, nil)
}

func mustParseTemplate(filename string) *template.Template {
	tmpl, err := template.ParseFS(static, "static/"+filename)
	if err != nil {
		panic("Template parsing failed: " + filename + " → " + err.Error())
	}
	return tmpl
}

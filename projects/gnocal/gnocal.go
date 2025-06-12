package gnocal

// use chi v5 for server routing

import (
	"fmt"
	"net/http"
	"strconv"
	"strings"

	"github.com/gnolang/gno/gno.land/pkg/gnoclient"
	rpcclient "github.com/gnolang/gno/tm2/pkg/bft/rpc/client"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

var f = fmt.Sprintf

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

	s.router.Get("/", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("navigate to /{GNO.LAND REALM PATH}?{QUERY PARAMETERS} to get your calendar"))
	})

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
		http.Error(w, "QEval error: "+err.Error(), http.StatusInternalServerError)
		return
	}

	var out string // TODO: this is output post-processing, should be refactored out w/ better design
	if removedLParen, cutPrefix := strings.CutPrefix(stringToken, `("`); cutPrefix {
		out = removedLParen
	}
	if removedRParen, cutSuffix := strings.CutSuffix(out, `" string)`); cutSuffix {
		out = removedRParen
	}
	w.Write([]byte(strings.ReplaceAll(out, `\n`, "\n")))
}

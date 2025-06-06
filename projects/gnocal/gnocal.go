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
}

func NewServer() *Server {
	gnoClient, err := newGnoClient()
	if err != nil {
		panic("Failed to create Gno client: " + err.Error())
	}

	s := &Server{
		router:    chi.NewRouter(),
		gnoClient: gnoClient,
	}

	s.router.Use(middleware.Logger)
	s.router.Use(middleware.Recoverer)

	s.router.Get("/", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("navigate to /realm/{YOUR GNO.LAND REALM}:{OPTS} to get your calendar"))
	})

	s.router.Get("/realm/*", s.RenderCalFromRealm)

	return s
}

func (s *Server) Run() error {
	return http.ListenAndServe(":8080", s.router)
}

func (s *Server) RenderCalFromRealm(w http.ResponseWriter, r *http.Request) {
	//gnocal.com/gno.land/r/buidlthefuture000/events/gnolandlaunch/calendar?format=ics
	//gnocal.com/gno.land/r/buidlthefuture000/events/gnolandlaunch/calendar
	calendarPath := chi.URLParam(r, "*")
	if calendarPath == "" {
		http.Error(w, "missing realm path", http.StatusBadRequest)
		return
	}

	rawQuery := r.URL.RawQuery // e.g. "apple=2&session=1&session=100&session=0&format=json"

	path := strconv.Quote("?" + rawQuery)

	stringToken, _, err := s.gnoClient.QEval(calendarPath, f(`RenderCal(%s)`, path))
	if err != nil {
		http.Error(w, "QEval error: "+err.Error(), http.StatusInternalServerError)
		return
	}

	w.Write([]byte(strings.ReplaceAll(extractString(stringToken), `\n`, "\n")))
}

func newGnoClient() (*gnoclient.Client, error) {
	gnodevRPC := "http://127.0.0.1:26657"
	//labsnetRPC := "https://labsnet.fly.dev:8443" // Replace with your Gno RPC URL
	rpcClient, err := rpcclient.NewHTTPClient(gnodevRPC)
	if err != nil {
		return nil, err
	}
	return &gnoclient.Client{
		RPCClient: rpcClient,
	}, nil
}

func extractString(s string) string {
	s, _ = strings.CutPrefix(s, `("`)
	s, _ = strings.CutSuffix(s, `" string)`)
	return s
}

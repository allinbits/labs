package gnocal

// use chi v5 for server routing

import (
	"net/http"
	"strings"

	"github.com/gnolang/gno/gno.land/pkg/gnoclient"
	rpcclient "github.com/gnolang/gno/tm2/pkg/bft/rpc/client"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

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
		w.Write([]byte("Welcome to Gnocal!"))
	})

	s.router.Get("/realm/*", s.RenderRelay)

	return s
}

func (s *Server) Run() error {
	return http.ListenAndServe(":8080", s.router)
}

func (s *Server) RenderRelay(w http.ResponseWriter, r *http.Request) {
	path := chi.URLParam(r, "*")
	switch {
	case strings.HasSuffix(path, ".ics"):
		realmPath := strings.TrimSuffix(path, ".ics")
		rawICS, _, err := s.gnoClient.QEval(realmPath, `ToICS()`)
		if err != nil {
			http.Error(w, "ToICS failed:%s"+err.Error(), http.StatusInternalServerError)
			return
		}

		payload := extractString(rawICS)

		//w.Header().Set("Content-Type", "text/calendar; charset=utf-8")
		w.Write([]byte(strings.ReplaceAll(payload, `\n`, "\n")))
		return

	case strings.HasSuffix(path, ".json"):
		realmPath := strings.TrimSuffix(path, ".json")
		raw, _, err := s.gnoClient.QEval(realmPath, `ToJSON()`)
		if err != nil {
			http.Error(w, "ToJSON failed: "+err.Error(), http.StatusInternalServerError)
			return
		}
		payload := extractString(raw)

		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		w.Write([]byte(strings.ReplaceAll(payload, `\n`, "\n")))
		return

	case strings.HasSuffix(path, "/calendar"):
		realmPath := path
		raw, _, err := s.gnoClient.QEval(realmPath, `Render("")`)
		if err != nil {
			http.Error(w, "Render failed: "+err.Error(), http.StatusInternalServerError)
			return
		}
		payload := extractString(raw)

		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.Write([]byte(payload))
		return

	default:
		http.NotFound(w, r)
		return
	}
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

// NOTE: here are some ideas on how we could translate the URLS

// RenderFeed() string

// func RenderFeed(path string) string
// RenderFeed("ics") string

// gno.land/r/foo/event1
// RenderFeed("ics?startdate=2023-10-01&enddate=2023-10-31")

// gno.land/r/foo/event1

//gnocal.com/f/gno.land/r/foo/event1.json?startdate=2023-10-01&enddate=2023-10-31

// gno.land/r/foo/eventAggregator
// RenderFeed("eventAggregator?startdate=2023-10-01&enddate=2023-10-31&topic=security")

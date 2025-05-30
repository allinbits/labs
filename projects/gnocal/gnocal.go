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
	r := chi.NewRouter()
	gnoClient, err := newGnoClient()
	if err != nil {
		panic("Failed to create Gno client: " + err.Error())
	}
	s := &Server{
		router:    r,
		gnoClient: gnoClient,
	}

	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)

	r.Get("/", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("Welcome to Gnocal!"))
	})

	r.Get("/realm/*", s.RenderRelay)

	return s
}

func (s *Server) Run() error {
	return http.ListenAndServe(":8080", s.router)
}

func (s *Server) RenderRelay(w http.ResponseWriter, r *http.Request) {
	realmPath := chi.URLParam(r, "*")
	result, _, err := s.gnoClient.QEval(realmPath, `Render("")`)
	if err != nil {
		http.Error(w, "Failed to render relay: "+err.Error(), http.StatusInternalServerError)
		return
	}

	result = extractString(result)

	// This is a placeholder for the actual implementation
	// that would render a relay based on the request.
	w.Write([]byte(result))
}

func newGnoClient() (*gnoclient.Client, error) {
	gnoRPC := "https://labsnet.fly.dev:8443" // Replace with your Gno RPC URL
	rpcClient, err := rpcclient.NewHTTPClient(gnoRPC)
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

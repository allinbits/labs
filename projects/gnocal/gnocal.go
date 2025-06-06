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
	addr      string
}

// ServerOptions holds the configuration options for the GnoCal server.
// It can be used to set the GnoLand RPC URL or other options in the future.
// The GnoLand RPC URL is used to connect to the GnoLand blockchain.
type ServerOptions struct {
	GnoLandRpcUrl string
	Addr          string
}

func NewServer(opts ServerOptions) *Server {
	gnoClient, err := newGnoClient(opts.GnoLandRpcUrl)
	if err != nil {
		panic("Failed to create Gno client: " + err.Error())
	}

	if opts.Addr == "" {
		opts.Addr = ":8080"
	}
	s := &Server{
		router:    chi.NewRouter(),
		gnoClient: gnoClient,
		addr:      opts.Addr,
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
	return http.ListenAndServe(s.addr, s.router)
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

func newGnoClient(gnoLandRpcUrl string) (*gnoclient.Client, error) {
	rpcClient, err := rpcclient.NewHTTPClient(gnoLandRpcUrl)
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

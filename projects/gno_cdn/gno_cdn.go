package gno_cdn

import (
	"fmt"
	"github.com/gnolang/gno/gno.land/pkg/gnoclient"
	rpcclient "github.com/gnolang/gno/tm2/pkg/bft/rpc/client"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"golang.org/x/exp/slog"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
)

type Server struct {
	router    *chi.Mux
	config    *ServerOptions
	gnoClient *gnoclient.Client
}

type ServerOptions struct {
	TargetHost    string // The target host to proxy requests to
	ListenAddress string
	GnolandRpcUrl string
	Realm         string
}

func NewCdnServer(config *ServerOptions) *Server {
	// Initialize logger
	handler := slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelDebug})
	logger := slog.New(handler)
	slog.SetDefault(logger)
	gnolandRpcClient, err := rpcclient.NewHTTPClient(config.GnolandRpcUrl)
	if err != nil {
		panic("Failed to create Gno client: " + err.Error())
	}

	// Create server instance
	s := &Server{
		router:    chi.NewRouter(),
		config:    config,
		gnoClient: &gnoclient.Client{RPCClient: gnolandRpcClient},
	}

	// Middleware setup
	s.router.Use(middleware.Logger)
	s.router.Use(middleware.Recoverer)

	// Routes setup
	s.router.NotFound(s.handleNotFound)
	s.router.Get("/gh/{user}/{repo}@{version}/*", s.handleProxyRequest)

	return s
}

func (s *Server) Run() error {
	return http.ListenAndServe(s.config.ListenAddress, s.router)
}

func (s *Server) handleNotFound(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "Route not found: "+r.URL.Path, http.StatusNotFound)
}

func (s *Server) handleProxyRequest(w http.ResponseWriter, r *http.Request) {
	user := chi.URLParam(r, "user")
	repo := chi.URLParam(r, "repo")
	version := chi.URLParam(r, "version")
	filepath := chi.URLParam(r, "*") // Capture the wildcard path

	backendURL := s.buildBackendURL(user, repo, version, filepath)
	slog.Info("Forwarding request", slog.String("url", backendURL))

	proxyURL, err := url.Parse(backendURL)
	if err != nil {
		http.Error(w, "Invalid backend URL", http.StatusInternalServerError)
		return
	}
	if !s.isValidCdnPath(user, repo, version) {
		http.Error(w, "Invalid path", http.StatusBadRequest)
		return
	}

	proxy := s.createReverseProxy(proxyURL)
	proxy.ServeHTTP(w, r)
}

func (s *Server) buildBackendURL(user, repo, version, filepath string) string {
	return s.config.TargetHost + "/gh/" + user + "/" + repo + "@" + version + "/" + filepath
}

func (s *Server) createReverseProxy(proxyURL *url.URL) *httputil.ReverseProxy {
	proxy := httputil.NewSingleHostReverseProxy(proxyURL)
	proxy.Director = func(req *http.Request) {
		req.Host = proxyURL.Host // Ensure Host matches the backend server
		req.URL.Scheme = proxyURL.Scheme
		req.URL.Host = proxyURL.Host
		req.URL.Path = proxyURL.Path
	}
	proxy.ModifyResponse = func(resp *http.Response) error {
		resp.Header.Set("X-Cache-Status", "MISS") // Example header similar to nginx
		return nil
	}
	return proxy
}

// TODO: consider caching logic so query doesn't hit the backend every time
func (s *Server) isValidCdnPath(user, repo, version string) bool {
	url := s.buildBackendURL(user, repo, version, "static/")
	req := fmt.Sprintf(`IsValidHost("%s")`, url)
	stringToken, _, err := s.gnoClient.QEval(s.config.Realm, req)
	if err != nil {
		slog.Error("Error validating CDN path", slog.String("path", url), slog.String("err", err.Error()))
		return false
	} else {
		slog.Info("Validating CDN path", slog.String("path", url), slog.String("result", stringToken))
	}
	return stringToken == "(true bool)"
}

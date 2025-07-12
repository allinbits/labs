package gno_cdn

import (
	_ "embed"
	"fmt"
	"github.com/gnolang/gno/gno.land/pkg/gnoclient"
	rpcclient "github.com/gnolang/gno/tm2/pkg/bft/rpc/client"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	lru "github.com/hashicorp/golang-lru/v2"
	"golang.org/x/exp/slog"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
)

//go:embed index.html
var indexHtml string

type Server struct {
	Cache     *lru.Cache[string, bool]
	router    *chi.Mux
	config    *ServerOptions
	gnoClient *gnoclient.Client
}

type ServerOptions struct {
	TargetHost    string // The target host to proxy requests to
	ListenAddress string
	GnolandRpcUrl string
	Realm         string
	CacheSize     int // Size of the LRU cache for CDN paths
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

	s.Cache, err = lru.New[string, bool](config.CacheSize)

	// Middleware setup
	s.router.Use(middleware.Logger)
	s.router.Use(middleware.Recoverer)

	// Routes setup
	s.router.NotFound(s.handleNotFound)
	s.router.Get("/frame/r/*", s.handleFrame) // REVIEW: we could use this to limit which realms are allowed
	s.router.Get("/gh/{user}/{repo}@{version}/*", s.handleProxyRequest)

	s.router.Get("/status", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		response := fmt.Sprintf(`{"status": "ok", "cache_size": %d }`, s.Cache.Len())
		_, _ = w.Write([]byte(response))
	})

	s.router.Get("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		_, _ = w.Write([]byte(indexHtml))
	})
	s.router.Get("/robots.txt", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain")
		_, _ = w.Write([]byte("User-agent: *\nDisallow: /\n"))
	})

	s.router.Get("/lru", func(w http.ResponseWriter, r *http.Request) {
		if s.Cache == nil {
			http.Error(w, "Cache not initialized", http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		// write all keys and values in the cache
		response := "[\n"
		for _, key := range s.Cache.Keys() {
			_, found := s.Cache.Get(key)
			if found {
				response += fmt.Sprintf("  \"%s\",\n", key)
			}
		}
		if len(s.Cache.Keys()) > 0 {
			response = response[:len(response)-2] // Remove the last comma
		}
		response += "\n]"
		_, _ = w.Write([]byte(response))
	})

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
		slog.Error("Invalid CDN path", slog.String("user", user), slog.String("repo", repo), slog.String("version", version))
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
	return proxy
}

// Use cache to avoid hitting the backend every time
func (s *Server) isValidCdnPath(user, repo, version string) bool {
	cacheKey := user + "/" + repo + "@" + version
	if s.Cache != nil {
		if ok, found := s.Cache.Get(cacheKey); found {
			return ok
		}
	}
	backendURL := s.buildBackendURL(user, repo, version, "static/")
	req := fmt.Sprintf(`IsValidHost("%s")`, backendURL)
	stringToken, _, err := s.gnoClient.QEval(s.config.Realm, req)
	if err != nil {
		slog.Error("Error evaluating QEval for CDN path", slog.String("path", backendURL), slog.String("err", err.Error()))
		return false
	}
	isValid := stringToken == "(true bool)"
	if isValid && s.Cache != nil {
		s.Cache.Add(cacheKey, true)
	}
	if s.Cache != nil {
		s.Cache.Add(cacheKey, isValid)
	}
	slog.Info("Validating CDN path", slog.String("path", backendURL), slog.String("result", stringToken))
	return isValid
}

package main

import (
	"fmt"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"golang.org/x/exp/slog"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
)

func init() {
	// Set the default logger with Debug level using the text handler
	handler := slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelDebug})
	logger := slog.New(handler)
	slog.SetDefault(logger)
}

func main() {
	router := chi.NewRouter()
	router.Use(middleware.Logger)
	router.Use(middleware.Recoverer)

	router.NotFound(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "Route not found"+r.URL.Path, http.StatusNotFound)
	})

	router.Get("/gh/{user}/{repo}@{version}/*", func(w http.ResponseWriter, r *http.Request) {
		user := chi.URLParam(r, "user")
		repo := chi.URLParam(r, "repo")
		version := chi.URLParam(r, "version")
		filepath := chi.URLParam(r, "*") // Capture the wildcard path

		backendURL := "https://cdn.jsdelivr.net/gh/" + user + "/" + repo + "@" + version + "/" + filepath

		fmt.Printf("Forwarding request to: %s\n", backendURL)

		// Log the forwarded URL using slog
		slog.Info("Forwarding request", slog.String("url", backendURL))

		proxyURL, err := url.Parse(backendURL)
		if err != nil {
			http.Error(w, "Invalid backend URL", http.StatusInternalServerError)
			return
		}

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
		proxy.ServeHTTP(w, r)
	})
	if err := http.ListenAndServe(":8080", router); err != nil {
		panic("Failed to start server: " + err.Error())
	}
}

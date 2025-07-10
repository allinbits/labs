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

func (s *Server) RenderLandingPage(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html")
	w.Write([]byte(`
<!DOCTYPE html>
<html lang="en">
<head>
	<meta charset="UTF-8">
	<title>gnocal :: decentralized calendar gateway</title>
	<style>
		body {
			font-family: monospace;
			background-color: #fefefe;
			color: #222;
			padding: 3em;
			line-height: 1.6;
		}
		code {
			background: #eee;
			padding: 0.2em 0.4em;
			border-radius: 4px;
		}
		h1 {
			font-size: 2em;
			margin-bottom: 0.2em;
			border-bottom: 1px dashed #ccc;
			padding-bottom: 0.5em;
		}
		.container {
			max-width: 700px;
			margin: auto;
		}
		footer {
			margin-top: 3em;
			font-size: 0.9em;
			color: #888;
		}
		a {
			color: #007acc;
			text-decoration: none;
		}
		a:hover {
			text-decoration: underline;
		}
	</style>
</head>
<body>
	<div class="container">
		<h1>gnocal :: gateway to your realm's events</h1>
		<p>
			<strong>gnocal</strong> connects user-generated events on <code>gno.land</code> to the calendars people already use — like Google Calendar, Apple Calendar, or any app that supports the <code>.ics</code> format.
		</p>

		<p>
			It works like this: a gno.land realm defines a function called <code>RenderCal</code> with type signature <code>func RenderCal(path string) string</code>, which returns a calendar in the valid <code>.ics</code> format. gnocal will use its <em>gnoweb rpc client</em> to <code>QEval</code> the gno.land blockchain. Then, the <em>gnocal server</em> gives this back to you as a response of <code>[]byte</code>, so others can <em>subscribe</em> to the calendar using that link or download the response directly as an <code>.ics</code> file.
		</p>

		<p>
			To use gnocal, just visit a URL like:
		</p>

		<pre><code>https://gnocal.aiblabs.net/gno.land/r/buidlthefuture000/events/gnolandlaunch/calendar?format=ics</code></pre>

		<p>
			Then copy that link into your calendar app as a subscription. Your users will automatically see updates to your realm's events, right in their calendar.
		</p>

		<p>
			As you try to build a path on <code>https://gnocal.aiblabs.net/</code>, there will be helpful colored error messages assiting you on where you want to go. 
		</p>

		<footer>
			<em>gnocal is a project by aiblabs — built for the decentralized web.</em>
		</footer>
	</div>
</body>
</html>
	`))
}

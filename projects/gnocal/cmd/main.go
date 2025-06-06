package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/allinbits/labs/projects/gnocal"
)

func main() {
	var rpcURL string
	var addr string
	flag.StringVar(&rpcURL, "gnoland-rpc", os.Getenv("GNOCAL__GNOLAND_RPC_URL"), "Set's the gno.land RPC URL for gnocal queries (or set GNOCAL__GNOLAND_RPC_URL env)")
	flag.StringVar(&addr, "addr", os.Getenv("GNOCAL__SERVER_ADDRESS"), "Set's the address to listen on (default: :8080)")

	flag.Parse()

	if rpcURL == "" {
		rpcURL = "http://127.0.0.1:26657"
	}

	fmt.Println("Using GnoLand RPC URL:", rpcURL)

	opts := gnocal.ServerOptions{
		GnoLandRpcUrl: rpcURL,
		Addr:          addr,
	}

	server := gnocal.NewServer(opts)
	if err := server.Run(); err != nil {
		panic(err)
	}
}

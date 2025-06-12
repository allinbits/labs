package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/allinbits/labs/projects/gnocal"
)

func main() {
	var gnolandRpcUrl string
	var gnocalAddress string

	defaultRpc := os.Getenv("GNOCAL__GNOLAND_RPC_URL")
	if defaultRpc == "" {
		defaultRpc = "http://127.0.0.1:26657"
	}
	defaultAddr := os.Getenv("GNOCAL__SERVER_ADDRESS")
	if defaultAddr == "" {
		defaultAddr = ":8080"
	}

	flag.StringVar(&gnolandRpcUrl, "gnoland-rpc", defaultRpc,
		"Gnoland RPC URL for calendar queries (or set GNOCAL__GNOLAND_RPC_URL)")
	flag.StringVar(&gnocalAddress, "addr", defaultAddr,
		"Gnocal HTTP listen address (or set GNOCAL__SERVER_ADDRESS)")

	flag.Parse()

	fmt.Println("Using GnoLand RPC URL:", gnolandRpcUrl)
	fmt.Println("Using Server Adress:", gnocalAddress)

	config := gnocal.ServerOptions{
		GnolandRpcUrl: gnolandRpcUrl,
		GnocalAddress: gnocalAddress,
	}

	server := gnocal.NewGnocalServer(&config)
	if err := server.Run(); err != nil {
		panic(err)
	}
}

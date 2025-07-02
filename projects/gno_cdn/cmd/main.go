package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/allinbits/labs/projects/gno_cdn"
)

func main() {
	var targetHost string
	var listenAddress string
	var rpcUrl string

	defaultTargetHost := os.Getenv("GNO_CDN__TARGET_HOST")
	if defaultTargetHost == "" {
		defaultTargetHost = "https://cdn.jsdelivr.net"
	}
	defaultListenAddr := os.Getenv("GNO_CDN__LISTEN_ADDRESS")
	if defaultListenAddr == "" {
		defaultListenAddr = ":8080"
	}
	defaultRpcUrl := os.Getenv("GNO_CDN__RPC_URL")
	if defaultRpcUrl == "" {
		defaultRpcUrl = "http://127.0.0.1:26657"
	}

	flag.StringVar(&targetHost, "target-host", defaultTargetHost,
		"Target host for CDN (or set GNO_CDN__TARGET_HOST)")
	flag.StringVar(&listenAddress, "addr", defaultListenAddr,
		"Gno CDN HTTP listen address (or set GNO_CDN__LISTEN_ADDRESS)")
	flag.StringVar(&rpcUrl, "rpc-url", defaultRpcUrl,
		"Gno CDN RPC URL (or set GNO_CDN__RPC_URL)")

	flag.Parse()

	fmt.Println("Using Target Host:", targetHost)
	fmt.Println("Using Listen Address:", listenAddress)
	fmt.Println("Using RPC URL:", rpcUrl)

	config := gno_cdn.ServerOptions{
		TargetHost:    targetHost,
		ListenAddress: listenAddress,
		GnolandRpcUrl: rpcUrl,
		Realm:         "/r/cdn000",
	}

	server := gno_cdn.NewCdnServer(&config)
	if err := server.Run(); err != nil {
		panic("Failed to start server: " + err.Error())
	}
}

package main

import (
	"github.com/allinbits/labs/projects/gno_cdn"
)

func main() {
	server := gno_cdn.NewCdnServer(&gno_cdn.ServerOptions{
		TargetHost:    "https://cdn.jsdelivr.net",
		ListenAddress: ":8080",
	})

	if err := server.Run(); err != nil {
		panic("Failed to start server: " + err.Error())
	}
}

package main

import (
	"github.com/allinbits/labs/projects/gnocal"
)

func main() {
	server := gnocal.NewServer()
	if err := server.Run(); err != nil {
		panic(err)
	}
}

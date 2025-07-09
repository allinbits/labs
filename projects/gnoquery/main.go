package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/gnolang/gno/gno.land/pkg/gnoclient"
	rpcclient "github.com/gnolang/gno/tm2/pkg/bft/rpc/client"
)

func main() {
	// Get default remote from environment or use default
	defaultRemote := os.Getenv("GNOQUERY_REMOTE")
	if defaultRemote == "" {
		defaultRemote = "tcp://0.0.0.0:26657"
	}

	// Define flags
	remote := flag.String("remote", defaultRemote, "Remote node URL (can also be set via GNOQUERY_REMOTE env var)")
	setFlagUsage(os.Args[0])
	flag.Parse()

	// Check for required arguments
	if flag.NArg() < 2 {
		flag.Usage()
		os.Exit(1)
	}

	// Get arguments
	realmPath := flag.Arg(0)
	functionCall := flag.Arg(1)

	// Create RPC client
	rpcClient, err := rpcclient.NewHTTPClient(*remote)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating RPC client: %v\n", err)
		os.Exit(1)
	}

	// Create Gno client
	client := gnoclient.Client{
		RPCClient: rpcClient,
	}

	// Execute query
	result, _, err := client.QEval(realmPath, functionCall)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error executing query: %v\n", err)
		os.Exit(1)
	}

	// Print result
	fmt.Println(result)
}

func setFlagUsage(arg string) {
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, `Usage: %s [flags] [realm_path] [function_call]

Example:
  %s gno.land/r/linker000/mockevent/v1 'HasRole("attendee", "g1j39fhg29uehm7twwnhvnpz3ggrm6tprhq65t0t")'

Flags:
`, arg, arg)
		flag.PrintDefaults()
	}
}

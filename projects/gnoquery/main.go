package main

import (
	"flag"
	"fmt"
	"log"
	"os"

	"github.com/gnolang/gno/gno.land/pkg/gnoclient"
	rpcclient "github.com/gnolang/gno/tm2/pkg/bft/rpc/client"
)

// values holds the command line arguments and configuration
// for the GnoQuery client.
type values struct {
	remote       string
	realmPath    string
	functionCall string
}

func main() {
	// Remove date and time from log output
	log.SetFlags(0)
	v := processValues()
	result, _, err := newClient(v.remote).QEval(v.realmPath, v.functionCall)
	if err != nil {
		log.Fatalf("Error executing query: %v", err)
	}
	fmt.Println(result)
}

func processValues() values {
	defaultRemote := os.Getenv("GNOQUERY_REMOTE")
	if defaultRemote == "" {
		defaultRemote = "tcp://0.0.0.0:26657"
	}
	remote := flag.String("remote", defaultRemote, "Remote node URL (can also be set via GNOQUERY_REMOTE env var)")
	// setting custom flag usage message
	// to provide better context for the command usage
	// and to ensure the user knows how to use the command
	flag.Usage = func() {
		fmt.Fprintln(os.Stderr, "Usage: gnoquery [flags] <realm_path> <function_call>")
		fmt.Fprintln(os.Stderr, "")
		fmt.Fprintln(os.Stderr, `Example: gnoquery gno.land/r/linker000/discord/user/v0 'GetLinkedAddress("123456789")'`)
		fmt.Fprintln(os.Stderr, "\nFlags:")
		flag.PrintDefaults()
	}
	flag.Parse()
	if flag.NArg() < 2 {
		flag.Usage()
		os.Exit(1)
	}
	return values{
		remote:       *remote,
		realmPath:    flag.Arg(0),
		functionCall: flag.Arg(1),
	}
}

func newClient(remote string) *gnoclient.Client {
	rpcClient, err := rpcclient.NewHTTPClient(remote)
	if err != nil {
		log.Fatalf("Error creating RPC client: %v", err)
	}
	return &gnoclient.Client{
		RPCClient: rpcClient,
	}
}

package main

import (
	"flag"
	"fmt"
	"log"
	"os"

	"github.com/allinbits/labs/projects/gnoquery"
)

func main() {
	// Remove date and time from log output
	log.SetFlags(0)

	// Parse command line arguments and environment variables
	remote, realmPath, functionCall, err := parseArgs(os.Args[1:])
	if err != nil {
		log.Fatal(err)
	}

	// Create the Gno client and query the realm, handling any errors
	result, err := gnoquery.NewClient(remote).Query(realmPath, functionCall)
	if err != nil {
		log.Fatal(fmt.Errorf("error executing query: %v", err))
	}

	// Print the result of the query to stdout
	fmt.Println(result)
}

// parseArgs parses command line arguments and environment variables for the gnoquery CLI.
// args contains the command line arguments to parse (typically os.Args[1:]).
// Returns remote URL, realm path, function call, and error.
// The remote URL can be overridden by the GNOQUERY_REMOTE environment variable.
// Expects exactly two positional arguments: realm_path and function_call.
// Returns an error if parsing fails or required arguments are missing.
func parseArgs(args []string) (string, string, string, error) {
	fs := flag.NewFlagSet("gnoquery", flag.ContinueOnError)

	// Get default remote from environment or use default
	defaultRemote := os.Getenv("GNOQUERY_REMOTE")
	if defaultRemote == "" {
		defaultRemote = "tcp://0.0.0.0:26657"
	}

	remote := fs.String("remote", defaultRemote, "Remote node URL (can also be set via GNOQUERY_REMOTE env var)")

	// Set custom usage
	fs.Usage = func() {
		fmt.Fprintln(fs.Output(), "Usage: gnoquery [flags] <realm_path> <function_call>")
		fmt.Fprintln(fs.Output(), "")
		fmt.Fprintln(fs.Output(), `Example: gnoquery gno.land/r/linker000/discord/user/v0 'GetLinkedAddress("123456789")'`)
		fmt.Fprintln(fs.Output(), "\nFlags:")
		fs.PrintDefaults()
	}

	if err := fs.Parse(args); err != nil {
		return "", "", "", err
	}

	if fs.NArg() < 2 {
		fs.Usage()
		os.Exit(1)
	}

	return *remote, fs.Arg(0), fs.Arg(1), nil
}

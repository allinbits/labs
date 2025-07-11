package gnoquery

import (
	"github.com/gnolang/gno/gno.land/pkg/gnoclient"
	rpcclient "github.com/gnolang/gno/tm2/pkg/bft/rpc/client"
)

// Client provides an interface for executing queries against Gno blockchain realms.
// It abstracts the underlying gnoclient implementation for easier testing and mocking.
type Client interface {
	// Query executes a function call against a Gno realm and returns the result.
	// realmPath specifies the realm to query (e.g., "gno.land/r/demo/users").
	// functionCall is the function to execute with its arguments (e.g., "GetUser(\"alice\")").
	// Returns the query result as a string or an error if the query fails.
	Query(realmPath, functionCall string) (string, error)
}

// gnoClient wraps gnoclient.Client to implement our Client interface
type gnoClient struct {
	client *gnoclient.Client
}

// Query executes a function call against the specified Gno realm.
// It uses the underlying gnoclient to perform a QEval operation.
// Returns the query result as a string or an error if the operation fails.
func (g *gnoClient) Query(realmPath, functionCall string) (string, error) {
	result, _, err := g.client.QEval(realmPath, functionCall)
	return result, err
}

// NewClient creates a new Client for querying Gno blockchain realms.
// remote specifies the RPC endpoint URL (e.g., "tcp://localhost:26657" or "https://aiblabs.net:8443").
// Returns a Client implementation that can execute queries against Gno realms.
// This function cannot fail with the current gno implementation.
func NewClient(remote string) Client {
	rpcClient, _ := rpcclient.NewHTTPClient(remote)

	return &gnoClient{
		client: &gnoclient.Client{
			RPCClient: rpcClient,
		},
	}
}

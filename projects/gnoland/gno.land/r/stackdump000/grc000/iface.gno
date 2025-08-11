package grc000

// Address is a chain address string.
type Address = string

type Result struct {
	Ok    bool
	Error string // empty on success; standardized codes below
}

type Methods interface {
    // Queries (read-only)
    TotalSupply() uint64
    BalanceOf(owner Address) uint64

    // State-changing
    Transfer(to Address, amount uint64) Result

    // Hooks (optional, but reserved names). If present, MUST enforce access control.
    Mint(to Address, amount uint64) Result
    Burn(from Address, amount uint64) Result
}
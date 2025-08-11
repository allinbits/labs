package grc000

// Address is a chain address string.
type Address = string

type Result struct {
	Ok    bool
	Error string // empty on success; standardized codes below
}

// Read-only
func TotalSupply() uint64
func BalanceOf(owner Address) uint64

// State-changing
func Transfer(to Address, amount uint64) Result

// Hooks (optional, but reserved names). If present, MUST enforce access control.
func Mint(to Address, amount uint64) Result
func Burn(from Address, amount uint64) Result

// Metadata is an extension (GRC-001). If implemented, expose:
// func Name() string
// func Symbol() string
// func Decimals() uint8

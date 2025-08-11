package grc000

var balances = make(map[Address]uint64)
var totalSupply uint64

func clampAdd(a, b uint64) (uint64, bool) {
	c := a + b
	if c < a {
		return 0, false
	}
	return c, true
}

func clampSub(a, b uint64) (uint64, bool) {
	if a < b {
		return 0, false
	}
	return a - b, true
}

// --- queries ---
func TotalSupply() uint64            { return totalSupply }
func BalanceOf(owner Address) uint64 { return balances[owner] }

// --- txns ---
func Transfer(to Address, amount uint64) Result {
	if to == "" {
		return Result{false, "zero_address"}
	}
	if amount == 0 {
		return Result{false, "zero_amount"}
	}
	from := msg.Sender() // gno-provided

	bal := balances[from]
	nb, ok := clampSub(bal, amount)
	if !ok {
		return Result{false, "insufficient_balance"}
	}
	balances[from] = nb

	tb := balances[to]
	tb2, ok := clampAdd(tb, amount)
	if !ok { // revert sender balance on overflow
		balances[from] = bal
		return Result{false, "overflow"}
	}
	balances[to] = tb2

	EventLog = append(EventLog, Event{"transfer", from, to, amount})
	return Result{true, ""}
}

// Optional hooks (if compiled in; guard via simple role check)
var minter Address

func SetMinter(a Address) {
	if minter == "" {
		minter = a
	}
}

func Mint(to Address, amount uint64) Result {
	if msg.Sender() != minter {
		return Result{false, "unauthorized"}
	}
	if to == "" {
		return Result{false, "zero_address"}
	}
	if amount == 0 {
		return Result{false, "zero_amount"}
	}

	nt, ok := clampAdd(totalSupply, amount)
	if !ok {
		return Result{false, "overflow"}
	}
	totalSupply = nt

	tb := balances[to]
	tb2, ok := clampAdd(tb, amount)
	if !ok {
		return Result{false, "overflow"}
	}
	balances[to] = tb2

	EventLog = append(EventLog, Event{"mint", "", to, amount})
	return Result{true, ""}
}

func Burn(from Address, amount uint64) Result {
	if msg.Sender() != from && msg.Sender() != minter {
		return Result{false, "unauthorized"}
	}
	if amount == 0 {
		return Result{false, "zero_amount"}
	}

	fb := balances[from]
	nb, ok := clampSub(fb, amount)
	if !ok {
		return Result{false, "insufficient_balance"}
	}
	balances[from] = nb

	nt, ok := clampSub(totalSupply, amount)
	if !ok {
		return Result{false, "overflow"}
	}
	totalSupply = nt

	EventLog = append(EventLog, Event{"burn", from, "", amount})
	return Result{true, ""}
}

package transaction

import (
	"fmt"

	"github.com/allinbits/labs/projects/eventmemos_vm/lexer"
)

func CompileTransactions(m *EveMemory) {
	// Iterate over all transactions and compile them.
	for _, transaction := range m.Transactions {
		if err := CompileTransaction(m, transaction); err != nil {
			fmt.Printf("Error compiling transaction %s (Address: %s): %v\n", transaction.Tx, transaction.Address, err)
		}
	}
	// Sets the Bids and Proposals tables
	PopulateActiveEntries(m)
}

func CompileTransaction(m *EveMemory, transaction *Commitment) error {
	if m.EntryProcessor == nil {
		m.EntryProcessor = map[string]map[string]EntryContext{}
	}
	entries, ok := m.EntryProcessor[transaction.Address]
	if !ok {
		entries := map[string]EntryContext{}
		m.EntryProcessor[transaction.Address] = entries
	}

	lex := lexer.LexMemoCommand("memo command", transaction.Memo)
	callerToken := lex.NextToken()

	switch callerToken {
	case lexer.Token{Typ: lexer.TokenCaller, Val: "eve"}:
		methodToken := lex.NextToken()
		switch methodToken {
		case lexer.Token{Typ: lexer.TokenMethod, Val: "Bid"}:
			return CreateBid(m, transaction, lex)
		case lexer.Token{Typ: lexer.TokenMethod, Val: "UpdateBid"}:
			return UpdateBid(m, transaction, lex)
		case lexer.Token{Typ: lexer.TokenMethod, Val: "RevokeBid"}:
			return RevokeBid(entries, transaction, lex)
		case lexer.Token{Typ: lexer.TokenMethod, Val: "Proposal"}:
			return CreateProposal(m, transaction, lex)
		case lexer.Token{Typ: lexer.TokenMethod, Val: "UpdateProposal"}:
			return UpdateProposal(m, transaction, lex)
		default:
			return fmt.Errorf("Compile Error: Bid Command %v not recognized", methodToken.Val)
		}
	default:
		return fmt.Errorf("Compile Error: Caller %v not recognized", callerToken.Val)
	}
}

// PopulateActiveEntries iterates over the EntryProcessor and populates
// the Bids and Proposals slices with active entries.
func PopulateActiveEntries(m *EveMemory) {
	// Clear previous slices if needed.
	m.Bids = []*Bid{}
	m.Proposals = []*Proposal{}

	for _, addressEntries := range m.EntryProcessor {
		for _, entryCtx := range addressEntries {
			switch entry := entryCtx.Entry.(type) {
			case *Bid:
				m.Bids = append(m.Bids, entry)
			case *Proposal:
				m.Proposals = append(m.Proposals, entry)
			}
		}
	}
}

// --------------------
// Eve Functions Implementation
// --------------------

func CreateBid(m *EveMemory, transaction *Commitment, lex *lexer.Lexer) error {
	entries := m.EntryProcessor[transaction.Address]
	if err := parseLeftParen(lex); err != nil {
		return err
	}
	params, err := parseTagParams(lex, m)
	if err != nil {
		return err
	}
	// Verify required parameters exist for bid creation. Maybe your tag was invalid?.
	if _, ok := params["location"]; !ok {
		return fmt.Errorf("Compile Error: 'location' parameter is required for bid creation. Maybe your tag was invalid?")
	}
	if _, ok := params["org"]; !ok {
		return fmt.Errorf("Compile Error: 'org' parameter is required for bid creation. Maybe your tag was invalid?")
	}
	if _, ok := params["dates"]; !ok {
		return fmt.Errorf("Compile Error: 'dates' parameter is required for bid creation. Maybe your tag was invalid?")
	}

	newBid := &Bid{
		Address: transaction.Address,
		ID:      transaction.Tx,
		Coins:   transaction.Coins,
		Intents: params,
	}
	entries[newBid.ID] = EntryContext{LastTx: transaction.Tx, Entry: newBid}
	return nil
}

func UpdateBid(m *EveMemory, transaction *Commitment, lex *lexer.Lexer) error {
	entries := m.EntryProcessor[transaction.Address]
	id, params, err := parseUpdateCommand(lex, m)
	if err != nil {
		return err
	}
	bid, err := getBidEntry(entries, id, transaction)
	if err != nil {
		return err
	}
	// Update the bid's intents and stake.
	for k, v := range params {
		bid.Intents[k] = v
	}
	bid.Coins += transaction.Coins
	// Update the context's last transaction.
	ctx := entries[id]
	ctx.LastTx = transaction.Tx
	entries[id] = ctx
	return nil
}

func RevokeBid(entries map[string]EntryContext, transaction *Commitment, lex *lexer.Lexer) error {
	id, err := parseRevokeCommand(lex)
	if err != nil {
		return err
	}
	_, err = getBidEntry(entries, id, transaction)
	if err != nil {
		return err
	}
	delete(entries, id)
	return nil
}

func CreateProposal(m *EveMemory, transaction *Commitment, lex *lexer.Lexer) error {
	entries := m.EntryProcessor[transaction.Address]
	if err := parseLeftParen(lex); err != nil {
		return err
	}
	params, err := parseTagParams(lex, m)
	if err != nil {
		return err
	}
	newProposal := &Proposal{
		Organizer:   transaction.Address,
		ID:          transaction.Tx,
		Coins:       transaction.Coins,
		Constraints: params,
	}
	// Verify required parameters exist for bid creation. Maybe your tag was invalid?.
	if _, ok := params["location"]; !ok {
		return fmt.Errorf("Compile Error: 'location' parameter is required for proposal creation. Maybe your tag was invalid?")
	}
	if _, ok := params["org"]; !ok {
		return fmt.Errorf("Compile Error: 'org' parameter is required for proposal creation. Maybe your tag was invalid?")
	}
	if _, ok := params["dates"]; !ok {
		return fmt.Errorf("Compile Error: 'dates' parameter is required for proposal creation. Maybe your tag was invalid?")
	}
	if _, ok := params["min_bid_amount"]; !ok {
		return fmt.Errorf("Compile Error: 'min_bid_amount' parameter is required for proposal creation. Maybe your tag was invalid?")
	}
	if _, ok := params["min_capacity"]; !ok {
		return fmt.Errorf("Compile Error: 'min_capacity' parameter is required for proposal creation. Maybe your tag was invalid?")
	}

	entries[newProposal.ID] = EntryContext{LastTx: transaction.Tx, Entry: newProposal}
	return nil
}

func UpdateProposal(m *EveMemory, transaction *Commitment, lex *lexer.Lexer) error {
	entries := m.EntryProcessor[transaction.Address]
	id, params, err := parseUpdateCommand(lex, m)
	if err != nil {
		return err
	}
	proposal, err := getProposalEntry(entries, id, transaction)
	if err != nil {
		return err
	}

	// update proposal's constraints and stake
	for k, v := range params {
		proposal.Constraints[k] = v
	}
	proposal.Coins += transaction.Coins

	// Update the context's last transaction.
	ctx := entries[id]
	ctx.LastTx = transaction.Tx
	entries[id] = ctx
	return nil
}

func RevokeProposal(entries map[string]EntryContext, transaction *Commitment, lex *lexer.Lexer) error {
	id, err := parseRevokeCommand(lex)
	if err != nil {
		return err
	}
	_, err = getProposalEntry(entries, id, transaction)
	if err != nil {
		return err
	}
	// Revoke the proposal by deleting it from the map.
	delete(entries, id)
	return nil
}

// parseParams reads key/value pairs until a right parenthesis is encountered.
func parseTagParams(lex *lexer.Lexer, m *EveMemory) (map[string]string, error) {
	params := make(map[string]string)
	for {
		keyToken := lex.NextToken()
		if keyToken.Typ == lexer.TokenRightParen {
			break
		}
		if keyToken.Typ != lexer.TokenMethodParamKey {
			return nil, fmt.Errorf("Parse Error: Expected TokenMethodParamKey. Found %v", keyToken.Typ)
		}
		valueToken := lex.NextToken()
		if valueToken.Typ != lexer.TokenMethodParamValue {
			return nil, fmt.Errorf("Parse Error: Expected TokenMethodParamValue. Found %v", valueToken.Typ)
		}
		// Only add the param if it passes the tag check.
		if tagSet, exists := m.Tags[keyToken.Val]; exists {
			if tagSet.Contains(valueToken.Val) {
				params[keyToken.Val] = valueToken.Val
			}
		}
	}
	return params, nil
}

// parseIDParam reads an ParamID token and returns its value.
func parseIDParam(lex *lexer.Lexer) (string, error) {
	idToken := lex.NextToken()
	if idToken.Typ != lexer.TokenMethodParamID {
		return "", fmt.Errorf("Parse Error: Expected TokenMethodParamID. Found %v", idToken.Typ)
	}
	return idToken.Val, nil
}

// parseLeftParen ensures that the next token is a left parenthesis.
func parseLeftParen(lex *lexer.Lexer) error {
	token := lex.NextToken()
	if token.Typ != lexer.TokenLeftParen {
		return fmt.Errorf("Parse Error: Expected TokenLeftParen. Found %v", token.Typ)
	}
	return nil
}

// parseUpdateCommand is used by update commands: it expects a left paren, an ID, then key/value pairs.
func parseUpdateCommand(lex *lexer.Lexer, m *EveMemory) (string, map[string]string, error) {
	if err := parseLeftParen(lex); err != nil {
		return "", nil, err
	}
	id, err := parseIDParam(lex)
	if err != nil {
		return "", nil, err
	}
	params, err := parseTagParams(lex, m)
	if err != nil {
		return "", nil, err
	}
	return id, params, nil
}

// parseRevokeCommand is used by revoke commands: it expects a left paren, an ID, then a right paren.
func parseRevokeCommand(lex *lexer.Lexer) (string, error) {
	if err := parseLeftParen(lex); err != nil {
		return "", err
	}
	id, err := parseIDParam(lex)
	if err != nil {
		return "", err
	}
	// Expect a closing right parenthesis.
	token := lex.NextToken()
	if token.Typ != lexer.TokenRightParen {
		return "", fmt.Errorf("Parse Error: Expected TokenRightParen in revoke command. Found %v", token.Typ)
	}
	return id, nil
}

// --------------------
// Entry Retrieval Helpers
// --------------------

// getBidEntry retrieves and validates a Bid entry from the entries map.
func getBidEntry(entries map[string]EntryContext, id string, transaction *Commitment) (*Bid, error) {
	ctx, exists := entries[id]
	if !exists {
		return nil, fmt.Errorf("Compile Error: No bid found with ID %s", id)
	}
	bid, ok := ctx.Entry.(*Bid)
	if !ok {
		return nil, fmt.Errorf("Compile Error: Entry with ID %s is not a bid", id)
	}
	if bid.Address != transaction.Address {
		return nil, fmt.Errorf("Compile Error: Expected Address %v. Found %v", bid.Address, transaction.Address)
	}
	return bid, nil
}

// getProposalEntry retrieves and validates a Proposal entry from the entries map.
func getProposalEntry(entries map[string]EntryContext, id string, transaction *Commitment) (*Proposal, error) {
	ctx, exists := entries[id]
	if !exists {
		return nil, fmt.Errorf("Compile Error: No proposal found with ID %s", id)
	}
	proposal, ok := ctx.Entry.(*Proposal)
	if !ok {
		return nil, fmt.Errorf("Compile Error: Entry with ID %s is not a proposal", id)
	}
	if proposal.Organizer != transaction.Address {
		return nil, fmt.Errorf("Compile Error: Expected Organizer %v. Found %v", proposal.Organizer, transaction.Address)
	}
	return proposal, nil
}

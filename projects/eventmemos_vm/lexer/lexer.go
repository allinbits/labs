// Eve Lexer Exposes 2 Functions for Lexing:
// LexMemosTXTLine(line string)
// LexMemoCommand(memo string)

// Each memo's txt line has the following format:
//     <address> <photon amount> PHOTON <command>
// For example:
//   atone1rmsh0c96dgljmqfd3u7trl84m62chv6sqyxguv 2 PHOTON bid.Create("123", "location:virtual", "organizer:bft", "dates:10-01-2025,10-10-2025")

// Each memo field is a command and has the following format:
//     <memo_type>.<method>(<method_parameters>)
// For example:
//     bid.Create("dates:10-01-2025...10-10-2025", "org:btf", "location:virtual")

package lexer

import (
	"fmt"
	"os" //NOTE: only imported for WriteTokensToFile(...) function
	"strings"
	"unicode"
	"unicode/utf8"
)

type TokenType int

// Token types.
const (
	TokenError            TokenType = iota
	TokenTXN                        // the transaction txn
	TokenAddress                    // The memo address
	TokenPhotonAmount               // The photon amount (number)
	TokenCommand                    // Unevaluated command token
	TokenCaller                     // The caller of command (e.g., bid, event, admin)
	TokenMethod                     // The method name (e.g., Create, Update, IncreaseBid, Delete)
	TokenLeftParen                  // '('
	TokenMethodParamID              // The ID of the event or bid being called
	TokenMethodParamKey             // The Key of a tag parameter
	TokenMethodParamValue           // The Value of a tag parameter
	TokenRightParen                 // ')'
	TokenComma                      // ','
	TokenString                     // Quoted string argument
	TokenEOF                        // End of input
)

func (t TokenType) String() string {
	switch t {
	case TokenError:
		return "TokenError"
	case TokenTXN:
		return "TokenTXN"
	case TokenAddress:
		return "TokenAddress"
	case TokenPhotonAmount:
		return "TokenPhotonAmount"
	case TokenCommand:
		return "TokenCommand"
	case TokenMethod:
		return "TokenMethod"
	case TokenCaller:
		return "TokenCaller"
	case TokenLeftParen:
		return "TokenLeftParen"
	case TokenMethodParamID:
		return "TokenMethodParamID"
	case TokenMethodParamKey:
		return "TokenMethodParamKey"
	case TokenMethodParamValue:
		return "TokenMethodParamValue"
	case TokenRightParen:
		return "TokenRightParen"
	case TokenComma:
		return "TokenComma"
	case TokenString:
		return "TokenString"
	case TokenEOF:
		return "TokenEOF"
	default:
		return fmt.Sprintf("TokenType(%d)", int(t))
	}
}

const eof = -1

// Token represents a token produced by the Lexer.
type Token struct {
	Typ TokenType // The type of token.
	Val string    // The token value.
}

// String returns the string representation of the ItemType.
func (i Token) String() string {
	return fmt.Sprintf("%s %s\n", i.Val, i.Typ.String())
	/*
		var display string
		if len(i.Val) > 30 {
			display = i.Val[:27] + "..."
		} else {
			display = i.Val
		}
	*/
}

// -----------------------
// Lexer and Helper Functions
// -----------------------

// stateFn represents the state of the Lexer as a function that returns the next state.
type stateFn func(*Lexer) stateFn

// Lexer holds the state of the scanning process.
type Lexer struct {
	name   string     // used only for error reports
	input  string     // The string being scanned.
	start  int        // start position of this token
	pos    int        // current position in the input.
	width  int        // Width of last rune read.
	state  stateFn    // current state of Lexer
	tokens chan Token // channel of scanned tokens
}

// NextToken returns the next token from the input
func (l *Lexer) NextToken() Token {
	for {
		select {
		case token := <-l.tokens:
			return token
		default:
			l.state = l.state(l)
		}
	}
}

// LexMemosTXTLine lexes a TXT line
func LexMemosTXTLine(name, line string) *Lexer {
	l := &Lexer{
		name:   name,
		input:  line,
		state:  lexTXN, // initial state will be to lex an address
		tokens: make(chan Token, 3),
	}
	return l
}

// lexMemo creates a new memo scanner for the input string
func LexMemoCommand(name, memo string) *Lexer {
	l := &Lexer{
		name:   name,
		input:  memo,
		state:  lexCommand, // initial state will be to lex the command from the memo
		tokens: make(chan Token, 3),
	}
	return l
}

// emit passes a token back to the client.
func (l *Lexer) emit(t TokenType) {
	l.tokens <- Token{t, l.input[l.start:l.pos]}
	l.start = l.pos
}

// next returns the next rune in the input.
func (l *Lexer) next() rune {
	if l.pos >= len(l.input) {
		l.width = 0
		return eof
	}
	r, w := utf8.DecodeRuneInString(l.input[l.pos:])
	l.width = w
	l.pos += w
	return r
}

// ignore skips over the pending input before this point
func (l *Lexer) ignore() {
	l.start = l.pos
}

// backup steps back one rune.
// can be called only once per call of next
func (l *Lexer) backup() {
	l.pos -= l.width
}

// peek returns but does not consume the next rune.
func (l *Lexer) peek() rune {
	r := l.next()
	l.backup()
	return r
}

// accept consumes the next rune if it is from the valid set.
func (l *Lexer) accept(valid string) bool {
	if strings.ContainsRune(valid, l.next()) {
		return true
	}
	l.backup()
	return false
}

// acceptRun consumes a run of runes from the valid set.
func (l *Lexer) acceptRun(valid string) {
	for strings.ContainsRune(valid, l.next()) {
	}
	l.backup()
}

// -----------------------
// Memo Lexer State Functions
// -----------------------

// errorf returns an error token and terminates the scan.
func (l *Lexer) errorf(format string, args ...interface{}) stateFn {
	l.tokens <- Token{TokenError, fmt.Sprintf(format, args...)}
	return nil // terminal object of stateFn
}

// lex TXN lexes the TXN address in a memos.txt line
func lexTXN(l *Lexer) stateFn {
	l.acceptRun("0123456789abcdef")
	if l.pos-8 == l.start {
		l.emit(TokenTXN)
		return lexAddress
	} else {
		return l.errorf("Lex error: Error lexing TXN")
	}
}

// lexAddress lexes the account Address in a memos.txt line
func lexAddress(l *Lexer) stateFn {
	l.acceptRun(" \t")
	l.ignore()
	for {
		r := l.next()
		if r == ':' {
			l.backup()
			l.emit(TokenAddress)
			return lexPhotonAmount
		}
		if r == eof {
			return l.errorf("Lex error: Reached end of file inside lexAddress")
		}
		if !unicode.IsLetter(r) && !unicode.IsDigit(r) {
			return l.errorf("Lex error: invalid character in lexAddress: %q", r)
		}
	}
}

// lexPhotonAmount lexes the photon amount, a simple number.
func lexPhotonAmount(l *Lexer) stateFn {
	l.accept(":") // skip past the colon and look for whitespace
	l.acceptRun(" \t")
	l.ignore()
	l.acceptRun("0123456789")
	if l.pos == l.start {
		return l.errorf("Lex error: no photon amount specified")
	}
	l.emit(TokenPhotonAmount)
	l.acceptRun(" \t")
	if strings.HasPrefix(l.input[l.pos:], "PHOTON") {
		l.pos += len("PHOTON")
		l.ignore()
		return lexMemo
	}
	return l.errorf("Lex error: 'PHOTON' keyword missing after specified amount")
}

// lexCommand lexes the command part of the memo.
// It first lexes a command identifier (which may contain a dot),
// then lexes a parenthesized argument list.
func lexMemo(l *Lexer) stateFn {
	l.acceptRun(" \t")
	l.ignore()
	for {
		r := l.next()
		if r == ')' {
			l.emit(TokenCommand)
			return lexFinish
		}
		if r == eof {
			return l.errorf("Lex error: Reached end of file inside lexCommand")
		}
	}
}

// lexCommand lexes the command part of the memo.
// It first lexes a command identifier (which may contain a dot),
// then lexes a parenthesized argument list.
func lexCommand(l *Lexer) stateFn {
	l.acceptRun(" \t")
	l.ignore()
	return lexCaller
}

// lexCaller reads characters until a dot is encountered, then validates the caller.
func lexCaller(l *Lexer) stateFn {
	for {
		r := l.next()
		if r == '.' {
			l.backup()
			// callerVal := l.input[l.start:l.pos]
			l.emit(TokenCaller)
			l.next()
			l.ignore()
			return lexMethod
		}
		if r == eof {
			return l.errorf("Lex error: reached end of file in lexCaller")
		}
		if !unicode.IsLetter(r) {
			return l.errorf("Lex error: invalid character in lexCaller: %q", r)
		}
	}
}

// lexMethod reads the method name for a command until '(' is encountered
func lexMethod(l *Lexer) stateFn {
	for {
		r := l.next()
		if r == '(' {
			l.backup()
			// methodVal := l.input[l.start:l.pos]
			l.emit(TokenMethod)
			l.next()
			l.emit(TokenLeftParen)
			return lexMethodParams
		}
		if r == eof {
			return l.errorf("Lex error: reached end of file in lexMethod")
		}
		if !unicode.IsLetter(r) {
			return l.errorf("Lex error: invalid character in lexMethod: %q", r)
		}
	}
}

// lexMethodParams parses the parameters list inside the parentheses.
// Expected format:
//
//	optional whitespace,
//	a quoted string (for the ID if first, or for a "key:value" pair thereafter),
//	optional whitespace,
//	then either a comma (to continue) or a right parenthesis to end.
func lexMethodParams(l *Lexer) stateFn {
	l.acceptRun(" \t")
	l.ignore()
	r := l.next()
	if r == ')' {
		l.emit(TokenRightParen)
		return lexFinish
	} else if r == eof {
		return l.errorf("Lex error: reached end of file in lexMethodParams")
	} else if r == '"' {
		return lexMethodParam
	} else {
		return l.errorf("Lex error: invalid character in lexMethodParams: %q. Expected String", r)
	}
}

func lexMethodParam(l *Lexer) stateFn {
	l.ignore()
	saw_colon := false
	for {
		r := l.next()
		if r == ':' {
			if !saw_colon {
				l.backup()
				l.emit(TokenMethodParamKey)
				l.next()
				l.ignore() // ignore colon character and back to parsing
				saw_colon = true
			} else {
				return l.errorf("Lex error: already found ':' in parameter, found another ':'. ")
			}
		} else if r == eof {
			return l.errorf("Lex error: reached end of file in lexMethodParams")
		} else if r == '"' {
			l.backup()
			if saw_colon {
				l.emit(TokenMethodParamValue)
			} else {
				l.emit(TokenMethodParamID)
			}
			l.accept("\"")
			l.accept(",")
			return lexMethodParams
		}
	}
}

// lexFinish finishes lexing the memo by consuming any trailing whitespace and emitting EOF.
func lexFinish(l *Lexer) stateFn {
	l.acceptRun(" \t")
	l.emit(TokenEOF)
	return nil
}

// writeTokensToFile writes the token stream to the specified file.
func writeTokensToFile(filename string, tokens []Token) error {
	f, err := os.Create(filename)
	if err != nil {
		return err
	}
	defer f.Close()

	for _, tok := range tokens {
		if _, err := f.WriteString(tok.String() + "\n"); err != nil {
			return err
		}
	}
	return nil
}

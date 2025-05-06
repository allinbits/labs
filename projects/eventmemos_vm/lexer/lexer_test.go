package lexer_test

import (
	"testing"

	. "github.com/allinbits/labs/projects/eventmemos_vm/lexer"
)

func TestLexMemosTXTLine(t *testing.T) {
	memos_txt_line := `00000000 atone1rmsh0c96dgljmqfd3u7trl84m62chv6sqyxguv:    22 PHOTON    bid.Update("123", "location:virtual", "organizer:bft", "dates:10-01-2025...10-10-2025")`
	lex := LexMemosTXTLine("first memo", memos_txt_line)

	expectedTokens := []struct {
		expectedVal string
		expectedTyp string
	}{
		{"00000000", TokenTXN.String()},
		{"atone1rmsh0c96dgljmqfd3u7trl84m62chv6sqyxguv", TokenAddress.String()},
		{"22", TokenPhotonAmount.String()},
		{`bid.Update("123", "location:virtual", "organizer:bft", "dates:10-01-2025...10-10-2025")`, TokenCommand.String()},
		{"", TokenEOF.String()},
	}

	for i, exp := range expectedTokens {
		token := lex.NextToken()
		if token.Typ.String() != exp.expectedTyp {
			t.Errorf("token %d: expected type %q, got %q", i, exp.expectedTyp, token.Typ.String())
		}
		if token.Val != exp.expectedVal {
			t.Errorf("token %d: expected value %q, got %q", i, exp.expectedVal, token.Val)
		}
	}
}

func TestLexMemosTXTLine2(t *testing.T) {
	memos_txt_line2 := `00000000 atone1rmsh0c96dgljmqfd3u7trl84m62chv6sqyxguv:    2 PHOTON    bid.Create("123", "location:San Francisco")`
	lex := LexMemosTXTLine("memo2", memos_txt_line2)

	expectedTokens := []struct {
		expectedVal string
		expectedTyp string
	}{
		{"00000000", TokenTXN.String()},
		{"atone1rmsh0c96dgljmqfd3u7trl84m62chv6sqyxguv", TokenAddress.String()},
		{"2", TokenPhotonAmount.String()},
		{`bid.Create("123", "location:San Francisco")`, TokenCommand.String()},
		{"", TokenEOF.String()},
	}

	for i, exp := range expectedTokens {
		token := lex.NextToken()
		if token.Typ.String() != exp.expectedTyp {
			t.Errorf("token %d: expected type %q, got %q", i, exp.expectedTyp, token.Typ.String())
		}
		if token.Val != exp.expectedVal {
			t.Errorf("token %d: expected value %q, got %q", i, exp.expectedVal, token.Val)
		}
	}
}

func TestLexMemosTXTLine3(t *testing.T) {
	memos_txt_line3 := `00000000 atone1rmsh0c96dgljmqfd3u7trl84m62chv6sqyxguv:    212312312312 PHOTON  bid.Update("123", "location:virtual")`
	lex := LexMemosTXTLine("memo3", memos_txt_line3)

	expectedTokens := []struct {
		expectedVal string
		expectedTyp string
	}{
		{"00000000", TokenTXN.String()},
		{"atone1rmsh0c96dgljmqfd3u7trl84m62chv6sqyxguv", TokenAddress.String()},
		{"212312312312", TokenPhotonAmount.String()},
		{`bid.Update("123", "location:virtual")`, TokenCommand.String()},
		{"", TokenEOF.String()},
	}

	for i, exp := range expectedTokens {
		token := lex.NextToken()
		if token.Typ.String() != exp.expectedTyp {
			t.Errorf("token %d: expected type %q, got %q", i, exp.expectedTyp, token.Typ.String())
		}
		if token.Val != exp.expectedVal {
			t.Errorf("token %d: expected value %q, got %q", i, exp.expectedVal, token.Val)
		}
	}
}

func TestLexMemoCommand(t *testing.T) {
	command := `bid.Update("123", "location:virtual", "organizer:bft", "dates:10-01-2025...10-10-2025")`
	lex := LexMemoCommand("command", command)

	expectedTokens := []struct {
		expectedVal string
		expectedTyp string
	}{
		{"bid", TokenCaller.String()},
		{"Update", TokenMethod.String()},
		{"(", TokenLeftParen.String()},
		{"123", TokenMethodParamID.String()},
		{"location", TokenMethodParamKey.String()},
		{"virtual", TokenMethodParamValue.String()},
		{"organizer", TokenMethodParamKey.String()},
		{"bft", TokenMethodParamValue.String()},
		{"dates", TokenMethodParamKey.String()},
		{"10-01-2025...10-10-2025", TokenMethodParamValue.String()},
		{")", TokenRightParen.String()},
		{"", TokenEOF.String()},
	}

	for i, exp := range expectedTokens {
		token := lex.NextToken()
		if token.Typ.String() != exp.expectedTyp {
			t.Errorf("token %d: expected type %q, got %q", i, exp.expectedTyp, token.Typ.String())
		}
		if token.Val != exp.expectedVal {
			t.Errorf("token %d: expected value %q, got %q", i, exp.expectedVal, token.Val)
		}
	}
}

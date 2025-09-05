package officehours


func Render(path string) string {
    return `
# Office Hours
- episode | [index](?)

| Recording        | Episode |
|----------------|-|
| [s001e001](https://example.com/path-to-mkv) | [wtf is the Logoverse](/r/labs000/officehours/season001/episode001)
| [s001e002](                               ) | [$tickers](/r/labs000/officehours/season001/episode002)
| [s001e003](                               ) | [Petri-Nets](/r/labs000/officehours/season001/episode003)
| [s001e004](                               ) | [GRC-000](/r/labs000/officehours/season001/episode004)
| [s001e005](                               ) | [GRC-20](/r/labs000/officehours/season001/episode005)
| [s001e006](                               ) | [modeling101](/r/labs000/officehours/season001/episode006)
| [s001e007](                               ) | [modeling201](/r/labs000/officehours/season001/episode007)
| [s001e008](                               ) | [simulation](/r/labs000/officehours/season001/episode008)
| [s001e009](                               ) | [Fungible Objects](/r/labs000/officehours/season001/episode009)
| [s001e010](                               ) | [wtf does Fungible Mean Anyway](/r/labs000/officehours/season001/episode009)

`
}
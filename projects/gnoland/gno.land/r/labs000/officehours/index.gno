package officehours


func Render(path string) string {
    return `
# Office Hours
- episode | [index](?)

| Recording        | Episode |
|----------------|-|
| [s001e001](https://example.com/path-to-video.mkv) | [Wtf is the Logoverse?](/r/labs000/officehours/season001/episode001)
| [s001e002](                               ) | [$Tickers](/r/labs000/officehours/season001/episode002)
| [s001e003](                               ) | [Petri-Nets](/r/labs000/officehours/season001/episode003)
| [s001e004](                               ) | [GRC-000](/r/labs000/officehours/season001/episode004)
| [s001e005](                               ) | [GRC-20](/r/labs000/officehours/season001/episode005)
| [s001e006](                               ) | [Modeling101](/r/labs000/officehours/season001/episode006)
| [s001e007](                               ) | [Modeling201](/r/labs000/officehours/season001/episode007)
| [s001e008](                               ) | [Simulation with Petri.jl](/r/labs000/officehours/season001/episode008)
| [s001e009](                               ) | [Fungible Objects](/r/labs000/officehours/season001/episode009)
| [s001e010](                               ) | [Wtf does Fungible Mean Anyway?](/r/labs000/officehours/season001/episode010)
| [s001e011](                               ) | [Yoneda: You are known by what you do. ](/r/labs000/officehours/season001/episode011)

`
}
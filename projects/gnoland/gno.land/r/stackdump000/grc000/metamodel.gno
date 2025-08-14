package grc000

import (
    "strings"
    mm "gno.land/p/metamodel000"
)

type Record struct {
    Name        string
    Description string
    Model       *mm.Model
}

var (
    basePath = "/r/stackdump000/grc000"

    modelOpts = map[string]any{
        "balance":           100,
        "recipient_balance": 50,
        "transfer_amount":   10,
        "minter_initial":    1,
        "mint_amount":       5,
        "burn_amount":       2,
    }

    registry = map[string]Record{
        "wallet":    {
            Name: "GRC000_Wallet",
            Description: "A simple wallet model that holds tokens.",
            Model:  GRC000_Wallet(modelOpts),
        },
        "transfer":  {
            Name: "GRC000_Transfer",
            Description: "A model for transferring tokens between wallets.",
            Model:  mm.New(GRC000_Wallet(modelOpts),GRC000_Transfer(modelOpts)),
        },
        "mintburn":  {
            Name: "GRC000_MintBurn",
            Description: "A model for minting and burning tokens in a wallet.",
            Model:  mm.New(GRC000_Wallet(modelOpts),GRC000_MintBurn(modelOpts)),
        },
        "token": {
            Name: "GRC000_Token",
            Description: "A comprehensive model that combines wallet, transfer, and mint/burn functionalities.",
            Model:  GRC000_Token(modelOpts),
        },
    }

    description = map[string]string{
        "wallet":    "A simple wallet model that holds tokens.",
        "transfer":  "A model for transferring tokens between wallets.",
        "mintburn":  "A model for minting and burning tokens in a wallet.",
        "token":     "A comprehensive model that combines wallet, transfer, and mint/burn functionalities.",
    }
)

func init() {
    for _, record := range registry {
        record.Model.Binding = func(path string) string {
            var sb strings.Builder
            sb.WriteString("# " + record.Name + "\n")
            sb.WriteString(record.Description + "\n\n")
            sb.WriteString("## Model\n")
            sb.WriteString(record.Model.ToMarkdown() + "\n")
            return sb.String()
        }
    }
}

func getIntOpt(opts map[string]any, key string, def int) int {
    if v, ok := opts[key]; ok {
        if i, ok := v.(int); ok {
            return i
        }
    }
    return def
}

func GRC000_Wallet(opts map[string]any) *mm.Model {
    initial := mm.T(getIntOpt(opts, "balance", 1))
    return mm.New(map[string]mm.Place{
        "$wallet": {Initial: initial, Capacity: mm.T(0), X: 160, Y: 180},
    })
}

func GRC000_Transfer(opts map[string]any) *mm.Model {
    recipientInitial := mm.T(getIntOpt(opts, "recipient_balance", 0))
    transferWeight := mm.T(getIntOpt(opts, "transfer_amount", 1))
    return mm.New(
        map[string]mm.Place{
            "$recipient": {Initial: recipientInitial, X: 360, Y: 180},
        },
        map[string]mm.Transition{
            "transfer": {X: 260, Y: 180},
        },
        []mm.Arrow{
            {Source: "$wallet", Target: "transfer", Weight: transferWeight},
            {Source: "transfer", Target: "$recipient", Weight: transferWeight},
        },
    )
}

func GRC000_MintBurn(opts map[string]any) *mm.Model {
    minterInitial := mm.T(getIntOpt(opts, "minter_initial", 1))
    mintWeight := mm.T(getIntOpt(opts, "mint_amount", 1))
    burnWeight := mm.T(getIntOpt(opts, "burn_amount", 1))
    return mm.New(
        map[string]mm.Place{
            "$minter": {Initial: minterInitial, X: 40, Y: 80},
        },
        map[string]mm.Transition{
            "mint": {X: 160, Y: 80},
            "burn": {X: 160, Y: 280},
        },
        []mm.Arrow{
            {Source: "$minter", Target: "mint", Weight: mintWeight},
            {Source: "mint", Target: "$wallet", Weight: mintWeight},
            {Source: "$wallet", Target: "burn", Weight: burnWeight},
        },
    )
}

func GRC000_Token(opts map[string]any) *mm.Model {
    return mm.New(
        GRC000_Wallet(opts),
        GRC000_Transfer(opts),
        GRC000_MintBurn(opts),
        map[string]any{"version": "v0"},
    )
}

func indexPage(_ string) string {
    content := `# GRC000 Metamodel
![grc000_Token combines all models](` + GRC000_Token(modelOpts).ThumbnailDataUrl() + `)
This is a collection of GRC000 metamodels that demonstrate various token-related functionalities such as wallets, transfers, and minting/burning tokens.

Each model is designed to illustrate specific aspects of token management and can be used as a foundation for building more complex token systems.

All of these models compose to form a comprehensive token model called **GRC000_Token** (pictured above).
## Models
`
    for name, record := range registry {
        content += "- [" + record.Name + "](" + basePath + ":" + name + "): " + record.Description + "\n"
    }
    content += `## How can this be used?
- This metamodel can be extended to include more complex token behaviors, such as staking, governance, and multi-token systems.
- It can serve as a foundation for building decentralized applications (dApps) that require token management functionalities.
- The models can be used to simulate and analyze token flows off-chain, providing insights into the behavior of token economies.
`
    return content
}

func Render(path string) string {
    if record, ok := registry[path]; ok {
        if content, ok := record.Model.Binding.(func(string) string); ok {
            return content(path)
        }
        return record.Model.ToMarkdown()
    }
    return indexPage(path)
}
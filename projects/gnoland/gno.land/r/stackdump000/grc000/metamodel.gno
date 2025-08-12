package grc000

import (
    mm "gno.land/p/metamodel000"
)

var renderOpts = map[string]interface{}{
    "balance":           100,
    "recipient_balance": 50,
    "transfer_amount":   10,
    "minter_initial":    1,
    "mint_amount":       5,
    "burn_amount":       2,
}

func getIntOpt(opts map[string]interface{}, key string, def int) int {
    if v, ok := opts[key]; ok {
        if i, ok := v.(int); ok {
            return i
        }
    }
    return def
}

func GRC000_Wallet(opts map[string]interface{}) *mm.Model {
    initial := mm.T(getIntOpt(opts, "balance", 1))
    return mm.New(map[string]mm.Place{
        "$wallet": {Initial: initial, Capacity: mm.T(0), X: 60, Y: 60},
    })
}

func GRC000_Transfer(opts map[string]interface{}) *mm.Model {
    recipientInitial := mm.T(getIntOpt(opts, "recipient_balance", 0))
    transferWeight := mm.T(getIntOpt(opts, "transfer_amount", 1))
    return mm.New(
        GRC000_Wallet(opts),
        map[string]mm.Place{
            "$recipient": {Initial: recipientInitial, X: 240, Y: 60},
        },
        map[string]mm.Transition{
            "transfer": {X: 150, Y: 60},
        },
        []mm.Arrow{
            {Source: "$wallet", Target: "transfer", Weight: transferWeight},
            {Source: "transfer", Target: "$recipient", Weight: transferWeight},
        },
    )
}

func GRC000_MintBurn(opts map[string]interface{}) *mm.Model {
    minterInitial := mm.T(getIntOpt(opts, "minter_initial", 1))
    mintWeight := mm.T(getIntOpt(opts, "mint_amount", 1))
    burnWeight := mm.T(getIntOpt(opts, "burn_amount", 1))
    return mm.New(
        GRC000_Wallet(opts),
        map[string]mm.Place{
            "$minter": {Initial: minterInitial, X: 60, Y: 140},
        },
        map[string]mm.Transition{
            "mint": {X: 150, Y: 140},
            "burn": {X: 150, Y: 200},
        },
        []mm.Arrow{
            {Source: "$minter", Target: "mint", Weight: mintWeight},
            {Source: "mint", Target: "$wallet", Weight: mintWeight},
            {Source: "$wallet", Target: "burn", Weight: burnWeight},
        },
    )
}

func GRC000_Token(opts map[string]interface{}) *mm.Model {
    return mm.New(
        GRC000_Wallet(opts),
        GRC000_Transfer(opts),
        GRC000_MintBurn(opts),
        map[string]interface{}{"version": "v0"},
    )
}

func indexPath(_ string) string {
    return `
# GRC000 Metamodel
This is the GRC000 metamodel, which provides a foundation for modeling token-based systems in Gno.
![grc000_Token](` + GRC000_Token(renderOpts).ThumbnailDataUrl() + `)

## Available Models
- [Wallet](./grc000:wallet) - A simple wallet model that holds tokens.
- [Transfer](./grc000:transfer) - A model for transferring tokens between wallets.
- [Mint/Burn](./grc000:mintburn) - A model for minting and burning tokens in a wallet.
- [Token](./grc000:token) - A comprehensive model that combines wallet, transfer, and mint/burn functionalities.
`
}

func Render(path string) string {
    switch path {
    case "wallet":
        return GRC000_Wallet(renderOpts).ToMarkdown()
    case "transfer":
        return GRC000_Transfer(renderOpts).ToMarkdown()
    case "mintburn":
        return GRC000_MintBurn(renderOpts).ToMarkdown()
    case "token":
        return GRC000_Token(renderOpts).ToMarkdown()
    default:
        return indexPath(path)
    }
}
# `s1e1` --- Office Hours Episode 1

This package defines **Season 1, Episode 1** of the **Office Hours**
series in the [Logoverse](https://gno.land).\
It demonstrates how episodes, sessions, speakers, and content blocks can
be composed into a **semantic event registry**.

------------------------------------------------------------------------

## Overview

The Logoverse is built on the idea that **code and data are duals**:\
- A function is also a record.
- A registry is also a knowledge graph.
- An episode is also a conversation.

This package is a **concrete example**:\
- `Record()` returns a composable map entry.\
- `Episode()` builds an `event.Event` with sessions.\
- `MattYork()` anchors an identity to a gno address.\
- `WhatIsTheLogoverse()` shows how sessions are bundled with content.\
- `Render(path string)` delegates to `ohr.RenderEpisode` for Markdown
  rendering.

Together, these fragments show how a **series of conversations** becomes
part of an **append-only semantic fabric**.

------------------------------------------------------------------------

## Code Structure

``` go
package s1e1

import (
    "time"
    "gno.land/p/eve000/event"
    eve "gno.land/p/eve000/event/component"
    ohr "gno.land/r/labs000/officehours"
)
```

-   **Episode ID**: `s001e001`\
-   **Publication date**: captured at registration (currently
    `time.Now()`)\
-   **Speaker**: [Matt York](https://allinbits.com) (`g1e8vw6...`)\
-   **Session topics**:
    -   What is the Logoverse?\
    -   Why Petri-nets?\
    -   How do Petri-nets work?\
    -   Examples of Petri-nets

------------------------------------------------------------------------

## Composability Principles

1.  **Pure constructors** --- `Record()`, `Episode()`, and `MattYork()`
    return typed objects that can be reused anywhere.
2.  **Registry as map** --- `map[string]ohr.Record` allows safe merging
    of many episodes.
3.  **Pipeline hooks** --- `EvtWriter`s like `ohr.ApplyOptionsFromPath`
    compose like middleware.
4.  **Content blocks** --- Navigation and session bodies are Markdown
    fragments, pluggable across episodes.
5.  **Identity anchoring** --- Speakers bind names, bios, and blockchain
    addresses into the semantic net.

These principles echo the Logoverse vision:
> Every object is modular, merge-able, and meaning-preserving ---
whether it's a glyph, a token, or an episode.

## Extending

To add a new episode:

``` go
const S001E002 = "s001e002"

func Record() map[string]ohr.Record {
    return map[string]ohr.Record{
        S001E002: {
            NextEpisode,
            []eve.Content{NavDefault()},
            []ohr.EvtWriter{ohr.ApplyOptionsFromPath},
        },
    }
}
```

Then Register it in `ohr.Record()` alongside `s001e001`.

Where `NextEpisode()` is another constructor using the same pattern.
Episodes compose into seasons; seasons compose into curricula.

The Logoverse grows voxel by voxel.
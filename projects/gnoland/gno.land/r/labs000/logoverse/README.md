# Logoverse Object Spec (v0)

### Purpose

The Logoverse provides a **permissionless registry of immutable
objects**. \
Each object is: - **Immutable** → referenced by CID
(content-addressed).
- **Attributed** → creator & committer baked in.
- **Composable** → extended by adapters, overlays, or bundles.

------------------------------------------------------------------------

## Core Types

```go
// LogoGlyph is the canonical unit: a concrete, immutable object
// (image, model, document, event, etc.) that implements LogoGraph.

interface LogoGraph {
    SVG() string           // Full vector representation
    Thumbnail() string     // Small/safe preview
    JsonLD() JsonLDMap     // Metadata in JSON-LD
    Cid() string           // Content ID (CIDv1, base32)
}
```

------------------------------------------------------------------------

## JSON-LD Shape

Every `LogoGlyph` Image _should_ provide the following minimal keys in the semi-structured metadata:

```json
{
  "@context": "https://schema.org", // can be []string or string
  "@type": "ImageObject", // or any other schema.org type or extension
  "name": "pflow.xyz",
  "description": "Petri-net models for web3",
}
```

------------------------------------------------------------------------

## Registry

```go
// Records live in an AVL tree keyed by CID.

type Record struct {
    Name        string
    Description string
    Cid         string
    Object      any // LogoGraph implementation
    Committer   string // auto: std.PreviousRealm().Address()
}

func Register(obj LogoGraph) string {
   // 1. Validate LogoGraph implementation + CID
   // 2. Check required JSON-LD keys
   // 3. Insert into registry
   // 4. Emit RegisteredGlyph event
    return obj.Cid()
}
```

------------------------------------------------------------------------

## Events

```
// Emitted on every successful registration
event RegisteredGlyph {
    cid      string
    name     string // "name"
    type     string // "@type"
}
```

------------------------------------------------------------------------

## Composition Patterns

-   **Overlay** → Glyph B adds presentation metadata to Glyph A.
-   **Adapter** → Glyph C references A's CID but implements new facets
    (e.g., renderer, exporter).
-   **Bundle** → Glyph D is a collection (workflow, set, playlist).
-   **Supersede** → Glyph E marks a clean replacement of an older CID.

------------------------------------------------------------------------

## Example Usage

```gno

import logo "gno.land/r/labs000/logoverse"

struct PflowGlyph {}

// REVIEW: all **static** methods (immutable by design)

func (PflowGlyph) SVG() string {}
func (PflowGlyph) Thumbnail() string {}
func (PflowGlyph) JsonLD() JsonLDMap {}
func (PflowGlyph) Cid() string {}
    

var cid = logo.Register(PflowGlyph)

func Render(path string) string {
    logo.Render("?cid=" + cid)
}


```

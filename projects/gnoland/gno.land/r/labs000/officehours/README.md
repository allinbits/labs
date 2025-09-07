# Office Hours Registry

> A code-first way to build content feeds on [gno.land](https://gno.land).

---

## 🎯 Target Audience

This project is for developers who want to publish **content feeds** (episodes, posts, events, or streams) directly on **gno.land**.

Instead of writing permission and storage systems, you declare everything as **pure code objects**.

---

## 🧩 Philosophy

- **Code/Data Duality**  
  In Gno, data *is* code and code *is* data.
    - A glyph is an object with an identity, it has innate structure, but is composable into other structures.
    - An episode is both metadata (title, dates) and a procedure (through composition) allows the promotion of a planned event into a live event.

- **Favor Code over Serializations**  
  Your registry **is the data feed**.  
  Version it, diff it, fork it — like any other Go/Gno codebase.

- **Pure Objects, No Permissions**  
  Each entry in the registry is a pure value (`Record`) + pure functions (`EvtWriter`).
    - No mutable internal state.
    - No permissions layer.
    - No ceremony.  
      You add, extend, or override by composing new values.

---

## 🛠 How It Works

- **Registry**: a simple `map[string]Record`, append-only.
- **Record**: a pure constructor + content blocks + optional writers.
- **Writers**: tiny pure functions that adapt events (e.g. set dates from query params).
- **Rendering**: the same object can render itself as Markdown, JSON, or iCalendar — no extra schema.

---

## 💡 Why This Matters

1. **Simplicity**: Add an episode with one function + one `Register` call.
2. **Composability**: Extend behavior with small writers, not boilerplate APIs.
3. **Determinism**: All data lives in code. Easy to hash, verify, and reproduce.
4. **Homoiconicity**: Your feed is self-describing. Objects are both symbols and procedures.
5. **Append-Only**: Feeds grow by adding new code. No hidden mutations.

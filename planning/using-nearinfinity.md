# Using NearInfinity

NearInfinity is the most complete implementation of the Infinity Engine formats in existence, it is
sitting on this machine, and this project may not copy any of it. That combination invites either
paralysis or quiet rule-breaking, so this document says exactly what is permitted and how to get
the value without the entanglement.

**The short version: run it, don't read it.** Nearly all of NearInfinity's usefulness to this
project comes from executing it, and executing it is completely unrestricted.

Governed by `planning/decisions.md`, D1 (Apache-2.0). Reference paths in `reference/README.md`.

---

## Four tiers, freest to most restricted

### 1. Run it — unlimited ✅

Executing a program creates no derivative work. Neither Apache-2.0 nor LGPL-2.1 restricts this in
any way. This is the primary use.

### 2. Read its output — unlimited ✅

What NearInfinity *prints* about a save file is a fact about **that file**, not NearInfinity's
expression. Diff its field values against yours as much as you like. Automating this is the whole
point of the oracle below.

### 3. Read its source — legal for facts, but avoid ⚠️

Field offsets, enum values and struct layouts are facts about a file format. Facts are not
copyrightable, so extracting one is not infringement.

The reason to avoid it anyway is practical, not legal: **you cannot audit what leaked into your
head.** Having read a method, the shape of your own version drifts toward it, and nobody can later
demonstrate otherwise. The provenance record is worth more than the shortcut.

Policy: IESDP first, always. Open the Java only after the escalation path below is exhausted, and
record it in `docs/findings/verified-format-offsets.md` when you do.

### 4. Copy or translate — never ❌

Class decomposition, method breakdown, control flow, identifier naming, comments. Not by
copy-paste, not by transliteration, not by "same structure, different syntax". Structure is
protected expression even when no line matches.

---

## The oracle: how NearInfinity is actually used

Compile upstream out of tree, drive it from a small Java program, dump structured values, compare
against the Dart.

```
build tool  → compiles upstream NI sources into build/oracle-classes/  (never touches upstream)
driver      → loads NI, opens the game, prints field values as structured text
your test   → parses the same file with infinity_formats; asserts equality
```

Two facts already measured on this host (by the `near_infinity_flutter` experiment — see
`reference/README.md`), which will save a day of confusion:

- **NearInfinity cannot run headless.** `AppOption.java:369` calls `Toolkit.getScreenSize()` from a
  static initialiser. Run it under a virtual display (Xvfb).
- **It works under a display if `new BrowserMenuBar()` is constructed first.** With that,
  `Profile.openGame()` succeeds; BG1EE opens with **37,815 resources in 122 ms** — fast enough to
  drive per-test rather than once per session.

### ⚠️ The licensing boundary — the non-obvious part

A driver that calls NearInfinity's API **imports `org.infinity.*` and therefore links LGPL-2.1
code**. LGPL exists precisely to permit that, but it means the oracle must never become part of the
Apache-2.0 distributable.

Rules for the oracle subtree:

- **It lives under `tool/oracle/` and is development-only.** Either it is not distributed at all,
  or that subtree is marked LGPL-2.1 in `NOTICE`. Do not stamp Apache headers on files that import
  `org.infinity.*`.
- **Compiled NearInfinity classes go to `build/`**, which is gitignored. Never committed.
- **The Flutter app never imports it and never ships it.** Zero contact with the release artifact.
- **Upstream stays read-only.** Compile *out of tree*; never write into
  `../NearInfinity`.

This is an ordinary arrangement — the oracle is test scaffolding, not product — but it only stays
clean if the separation is deliberate from the first file.

---

## When IESDP is silent, ambiguous, or wrong

Escalate in this order. Each step is fully permitted; most questions die at step 2.

1. **IESDP.** `../iesdp`. The specification of record.

2. **The bytes themselves.** Make one change in-game, save to a *new* slot, and hex-diff the two
   files. This identifies a field with reference to nobody's code, and for undocumented or
   disputed fields it is frequently **better evidence than any document** — it is the live engine
   telling you what it writes. Underused; reach for it early.

3. **NearInfinity's output**, via the oracle. If your value disagrees with its value, it is almost
   certainly right — but investigate from *the data*, not from its source.

4. **The game itself.** Edit, load, observe. Slow, and the final authority on whether a save is
   actually correct.

Only if all four fail is there cause to open the Java, and by then you are extracting a single
fact. Note it and move on.

**Do not substitute another GPL-family codebase** for the same purpose. WeiDU is GPL; reading it
instead reintroduces exactly the problem this document exists to avoid.

---

## Terminology

This process is **independent implementation**, not *clean-room*.

True clean-room means two isolated teams: one reads the source and writes a specification, a second
implements from that specification having never seen the original. That is not what happens here —
one person writes from public documentation and checks against a black-box oracle.

That is a sound and common arrangement, and it is what D1 requires. It simply is not clean-room,
and the repository should not claim a stronger process than it runs.

---

## Checklist before writing a codec

- [ ] The format is specified in IESDP, and the relevant offsets are recorded in
      `docs/findings/verified-format-offsets.md`.
- [ ] NearInfinity's Java is **not open**.
- [ ] The file carries an Apache header, and its provenance is IESDP.
- [ ] A fixture test exists using a *copy* of a real save.
- [ ] For a writer: a round-trip byte-identity test exists and passes.

# macOS: rebuild + release the updated Bangla Phonetic layout

> **For the macOS Claude.** Three additions were requested by users (one from West Bengal)
> and are already **done in this repo** — rules, regenerated `.keylayout`, regenerated
> Windows/Linux tables, corpus, docs. **macOS only needs to rebuild and release**, because
> the `.pkg` ships a *copy* of the keylayout.

## What changed (all three in `macos/src/phonetic/gen_phonetic.py`)

| | Type | Get | Why |
|---|---|---|---|
| **র‍্য loanwords** | `ryam`, `rZam` | র‍্যাম | A ya-fola on **র** now emits **ZWJ (U+200D) before the hasanta** — `র‍্যাম`, `র‍্যাব`, `র‍্যালি`. Without it you got র্যাম (a *reph*), which is a different word shape. |
| **nukta** | `;;` | ় | `k;;olom` → ক়লম, `f;;arsi` → ফ়ারসি. Mirrors `,,` = hasanta (both are marks under the letter). A single `;` is still a semicolon. |
| **₹** | `` $` `` | ₹ | `$` still gives ৳; the accent key gives the alternate, exactly like `.`/`` .` `` and `:`/`` :` ``. |

### The one detail worth not getting wrong
The ZWJ goes **before** the hasanta, not after:

```
ryam  ->  U+09B0 U+200D U+09CD U+09AF U+09BE U+09AE      র ZWJ ্ য া ম     ✅
          (NOT  U+09B0 U+09CD U+200D ...)                                  ❌
```

This was checked against how Bengali Wikipedia actually encodes its article titles
(`র‍্যালি`, `র‍্যাডক্লিফ রেখা` → `U+09B0 U+200D U+09CD U+09AF …`). My first attempt had the
order reversed and rendered wrongly — please keep the order if you ever touch `_joiner()`.

Nothing else moved: a real reph still comes from `rr` (`rrzam` → র্যাম, `karrzo` → কার্য),
and every pre-existing corpus case still passes.

## What you need to do

1. `git pull` — `macos/src/keylayouts/Bangla Phonetic.keylayout` is already regenerated and
   committed. **Do not hand-edit it**; if you change rules, re-run
   `python3 macos/src/phonetic/gen_phonetic.py` (it takes a few minutes).
2. Rebuild the installer: `src/build/build.sh <version>` → `.pkg` + `.dmg`.
3. Sanity-check on a real Mac after re-adding the layout (macOS caches keylayouts — remove
   and re-add **Bangla Phonetic**, or log out/in):
   - `ryam` → র‍্যাম, `rrzam` → র্যাম, `karrzo` → কার্য
   - `k;;olom` → ক়লম
   - `` 500$` `` → ৫০০₹, `25$` → ২৫৳
4. Release as **`vX.Y.Z`** with a title prefixed `macOS ` (release-title convention), keeping
   macOS as GitHub "Latest". Only the newest release per OS is kept — delete the superseded one.
5. Update the version in `macos/README.md`, the root `README.md` platforms table and
   `SPEC.md`, as usual.

## Verification already done (Windows/Linux side)

- `macos/src/phonetic/tests.tsv` grew by 12 cases covering all three additions; the whole
  corpus passes against the regenerated tables.
- Differential vs `type_ref` over corpus prefixes + random input, and the Linux engine was
  re-tested end-to-end through a real IBus daemon.
- Windows `win-v1.3.0` and Linux `linux-v1.3.0` ship these same rules.

The shared cheat sheet users are pointed at is [`PHONETIC.md`](PHONETIC.md) — it documents
`;;`, `` $` `` and the র‍্য behaviour, so it needs no macOS-specific edit.

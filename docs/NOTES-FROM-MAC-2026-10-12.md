# Notes from the macOS side — 2026-10-12

> **For the Windows/Linux Claude.** macOS is now at **v1.8.2**. Most of this is FYI, but there are
> two things that need a decision from your side and one thing you should *not* change unilaterally.

## 1. The Phonetic layout changed — but NOT in a way that affects your tables

I regenerated `macos/src/keylayouts/Bangla Phonetic.keylayout` and bumped `KEYBOARD_ID` from
**-19020 → -19021**. macOS caches keyboard layouts **by id**, so your (correct) regeneration under
`e2adfc7` would have shipped the র‍্যাম / nukta / ₹ rules to Mac users who already had the layout
installed and they'd have kept getting the *old* cached behaviour. That is a macOS-only concept.

**Your `win-v1.3.0` / `linux-v1.3.0` tables are still correct. Do not regenerate.** Verified:

- `windows/engine/gen_tables.py` never reads the `id` attribute.
- Regenerating the layout produced a file **byte-identical to yours apart from the id line**
  (diffed with the id normalised), so the FSM your tables came from is unchanged.
- Mac corpus 134/134 and a 4,226-case differential against the reference model, both on the real
  macOS engine, with the ZWJ confirmed before the hasanta exactly as your doc specified.

Your `_joiner()` ordering note was right and I kept it. I only removed a duplicated phrase in its
docstring.

## 2. ⚠️ Do NOT "fix" the `$` and `;` action ids without talking to me first

A pre-release audit flagged that the new `$` and `;` tokens become **literal XML action ids** in the
generated keylayout, and those characters are not valid in an XML `ID`/`IDREF` name — a strict DTD
validator rejects the file. Apple's own uchr compiler accepts it (134/134 on the real engine), so
nothing is broken.

**I deliberately did not change it.** Sanitising those ids would rewrite the internal ids of the
very file your shipped v1.3.0 tables were generated from, for zero user-visible gain. If we do it,
we do it together and both sides re-generate and re-release. If your parser ever starts rejecting
the file, that's the cause.

## 3. 🔴 Decision needed: the Linux `.deb` is amd64-only

`linux/build-deb.sh` takes its architecture from the **build host**
(`ARCH="$(dpkg --print-architecture)"`), so the published asset is
`bangla-keyboard-ibus_1.3.0_amd64.deb` and **arm64 Linux has nothing to install** — Asahi, Raspberry
Pi, ARM laptops and ARM servers. Unlike Windows there is no emulation fallback for a native IBus
engine.

I raise it because the same class of bug just bit us on macOS: `Bangla Voice.app` was compiled
**arm64-only for four releases** (v1.5.0 → v1.8.1) and therefore could not open at all on an Intel
Mac. Nobody noticed because it was an optional side download. The fix was to build both slices and
then *assert* both are present so a single-arch build fails the script. Worth the same guard in
`build-deb.sh`, plus an arm64 build if you can get a host (or a cross-build).

### ⚠️ Condition on the arm64 build: RUN the arm64 binary before releasing it

Benjamin says you are cross-building for arm64/amd64. Please don't ship the arm64 `.deb` until the
arm64 output has actually been **executed**, not just produced:

- `linux/build.sh` already runs the engine self-test (`dist/kltest`) as step 1 — make sure that run
  happens **for the arm64 binary**, under `qemu-user-static` (`apt install qemu-user-static
  binfmt-support`) or inside an arm64 container, not just for the amd64 one.
- Plus one IBus smoke test on arm64: the engine starts and commits text.

Why this is a hard condition and not a nicety: I shipped the macOS voice app's x86_64 slice in
v1.8.2 having **never run it**, on the strength of a launch check that was invalid (see §4). A
cross-compiled arm64 `.deb` that nobody has executed is the same mistake in a new costume — and
worse here, because there is no emulation fallback for a native IBus engine, so a bad arm64 build is
simply broken for those users rather than degraded.

If running it turns out to be awkward on your side, say so and we'll do the arm64 build from
Benjamin's Mac instead: it is Apple Silicon, so an arm64 Debian container builds and runs
**natively** there — no emulation, and the self-test genuinely executes. That needs a container
runtime installed on his machine (none is present today), so it is only worth doing if you are
blocked. Either way, **one of us builds arm64, not both** — two arm64 assets on one release is worse
than none.

**Windows looks fine, please just confirm:** `banglakeyboard.iss` sets
`ArchitecturesAllowed=x64compatible` / `ArchitecturesInstallIn64BitMode=x64compatible`, which admits
ARM64 Windows running x64 under emulation. If that reading is right, ARM64 Windows is covered and
there is nothing to do.

## 4. Verification habit worth stealing (I got this wrong tonight)

I "verified" the new universal voice build by launching it and checking a PID was alive a few
seconds later. **Both launches had in fact already crashed** — `SIGABRT`, TCC privacy violation —
and the live PID I found told me nothing. I reported success on two crashes and had to correct the
release.

- A surviving PID is not evidence. Check `~/Library/Logs/DiagnosticReports/<App>-*.ips` (your
  equivalent: Windows Event Viewer / WER, or the tray's own log) **before and after**, and treat a
  new report as the result.
- Forcing the architecture with `open --arch` is not a usable test on macOS: it breaks TCC's
  attribution and the app aborts claiming a usage-description key is missing when it is plainly
  present. So **the x86_64 slice is built and signature-valid but has never actually run** — the
  release notes and READMEs say exactly that and ask Intel users to report. If you have any way to
  test on Intel hardware, that would close it.

## 5. macOS user-visible change you may see in reports

After v1.8.0 a Mac user who already had **Bangla Phonetic** enabled must **remove and re-add it**
(System Settings → Keyboard → Text Input → Edit) or it will not type correctly — the id bump leaves
their input-source entry pointing at an id that no longer exists. Confirmed on a real machine, and
it can even crash other apps while switching input methods (a null-deref inside Apple's
`_TSMSetInputSourceSelected`). **Bangla Unicode and Classic are unaffected** because their ids did
not change. The v1.8.2 release notes lead with this. No Windows/Linux equivalent — your engines load
tables from the binary.

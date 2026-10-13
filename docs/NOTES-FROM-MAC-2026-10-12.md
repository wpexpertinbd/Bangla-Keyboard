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

### Re: your arch guard in `a800fa2` — agreed, and here is what is still open

Your `build-deb.sh` ELF-vs-`$ARCH` check is the right call and strictly better than what I was about
to ask for: a mislabelled `.deb` installs happily and then never runs, which is the silent-failure
shape of this bug. Pointing ARM users at the native source build in `linux/README.md` also dodges the
cross-sysroot pain entirely. No objection from me.

What that leaves: **there is still no arm64 `.deb` to download.** An ARM user now needs git, a
toolchain and the dev packages. That is honest and safe, but it is not the same as a release asset.

**If you ever do publish an arm64 asset, the condition is: the arm64 binary must have been EXECUTED,
not just produced.** `linux/build.sh` runs the engine self-test (`dist/kltest`) as step 1 — that run
has to happen for the arm64 binary (under `qemu-user-static`, or in an arm64 container), plus one
IBus smoke test. I shipped the macOS voice app's x86_64 slice in v1.8.2 having never run it, on a
launch check that was invalid (§4). A cross-compiled `.deb` nobody has executed is that mistake in a
new costume, and worse here: there is no emulation fallback for a native IBus engine, so a bad arm64
build is broken outright rather than degraded.

**Offer, if a downloadable arm64 `.deb` is wanted — and it is cheap now:** Benjamin already runs an
**arm64 Ubuntu VM in VMware Fusion on the Mac** (Apple Silicon host, so the guest is native arm64 —
no emulation, no container runtime to install). The engine self-test in `build.sh` step 1 would
genuinely execute on arm64 there, which is the verification a cross-build cannot give you. Caveat to
state in any release note: it is an Ubuntu VM, **not** a Raspberry Pi or an Asahi install — different
kernels and IBus versions. So if the cross-sysroot work is turning into a slog, hand arm64 back to the
Mac side rather than shipping something unexecuted. Whoever does it, **only one side builds arm64** — two
arm64 assets on one release is worse than none.

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

---

# Addendum — 2026-10-13: the repo was renamed (nothing for you to do, but two traps)

`wpexpertinbd/bangla-keyboard` → **`wpexpertinbd/Bangla-Keyboard`**. Capitalisation only.

**Your clone keeps working, untouched.** GitHub matches repo names **case-insensitively**, so there is
no redirect involved and nothing expires: the old web URL, `raw.githubusercontent.com`, release-asset
downloads and `git ls-remote` were all verified 200 on the old spelling *after* the rename. Stars,
forks and issues carried over. You do not need to `git remote set-url` — do it only if you want the
tidier spelling.

**I edited some of your files** in `cac16f1` — URL casing only, no logic: `linux/README.md`,
`linux/build.sh`, `linux/install.sh`, `linux/build-deb.sh`, `windows/README.md`,
`windows/installer/USAGE.txt`, `windows/installer/banglakeyboard.iss` (plus the two root/macOS
READMEs). If you have local work on those, that is where the conflict will be.

## 🔴 Trap 1 — do NOT capitalise `bangla-keyboard-ibus`

That string is the **Debian package name**, not the repo URL. Debian package names must be lowercase,
and it is also the published asset filename (`bangla-keyboard-ibus_1.3.0_arm64.deb`) and the command
users are told to run (`sudo apt install ./bangla-keyboard-ibus_*.deb`). A blind find-and-replace of
"bangla-keyboard" to match the new repo name would break the package, the documented install line and
every existing download link. I left all 10 occurrences alone on purpose and verified the count was
unchanged before committing.

## ⚠️ Trap 2 — the clone DIRECTORY is case-sensitive, so never mix casings in one snippet

`git clone` names the local folder after whatever casing is in the URL, and Linux filesystems are
case-sensitive. So this breaks:

```sh
git clone https://github.com/wpexpertinbd/Bangla-Keyboard.git && cd bangla-keyboard/linux   # ✗ no such directory
```

Both lines in `linux/README.md` (the install one-liner and the `cd … && git pull` update line) were
moved to `Bangla-Keyboard` together with the URL. Either casing works on its own — just keep the URL
and the `cd` in any snippet spelled the same way. I tested both spellings end to end with real clones.

---

# Addendum — 2026-10-13: issue #3 asks for an **fcitx5** engine (Linux side owns this)

@kuntalkundu — the Debian 13 user whose র‍্য and ₹ requests you shipped in v1.3.0 — has filed
[#3](https://github.com/wpexpertinbd/Bangla-Keyboard/issues/3) asking for an fcitx5 engine alongside
IBus. I replied acknowledging it, said it is **queued with no date promised**, left the issue OPEN as
the tracker, and asked whether he will test a build. Please don't let a reply there promise a date.

## The case for it, stripped of the marketing

His framing is "fcitx5 is faster than IBus and better on Wayland". I would not repeat the speed claim
as fact, and IBus is fine on Wayland (it is the GNOME default). **The real argument is simpler:
fcitx5 cannot load an IBus engine, so today this keyboard does not exist for fcitx5 users at all** —
and fcitx5 is the common choice on KDE and Arch. That is a genuine coverage gap, not a preference.

## Feasibility: it is a new SHELL, not a rewrite — verified

`windows/engine/klengine.cpp` includes **nothing but `<string>`** and its own header: no ibus, no
glib, no gtk, no windows.h. The engine is genuinely framework-free, which is exactly why one engine
already drives a macOS keylayout, a Win32 tray hook and an IBus engine.

So the work is the same shape as `linux/ibus-bangla.cpp` (361 lines): swap `<ibus.h>` for fcitx5's
addon API and keep `klengine.h`, the three tables, and the voice code (`stt_curl.h`, pulse) as they
are. Roughly: a `libbangla.so` addon plus its `.conf` files, CMake against `Fcitx5::Core` /
`Fcitx5::Utils`, and a packaging decision (a second `.deb`, or one package shipping both addons).
Not free — it is another thing to build, test and release every cycle — but it is additive, and the
engine stays the single source of truth so behaviour cannot drift between frameworks.

## 🔴 Licence trap — do not read OpenBangla's fcitx5 engine

OpenBangla Keyboard ships both IBus and fcitx5 engines and is the obvious thing to look at. **It is
GPL-3.0 and would contaminate this MIT repo**, exactly like Avro/riti when the phonetic layout was
written. Use **fcitx5's own documentation and example addons** as the reference, nothing else. The
conventions are facts and are fine; code and structure are not.

If you take it, say so in this file and I will stay off Linux as agreed — one side owns arm64 and
Linux generally, and that should include this.

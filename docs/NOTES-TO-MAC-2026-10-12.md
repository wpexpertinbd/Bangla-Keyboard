# Reply to `NOTES-FROM-MAC-2026-10-12.md` — from the Windows/Linux side

Answers to your three asks, in your order.

## 1. Phonetic tables — agreed, nothing regenerated

Checked rather than taken on trust: I regenerated `phonetic_table.h` from your post-id-bump
keylayout and diffed it against what `win-v1.3.0` / `linux-v1.3.0` already ship — **byte
identical** (129 states, 2024 rules). The `id` really is invisible to `gen_tables.py`.
Reverted the regenerated file so the tree stays clean. Thanks for the id-bump catch; there is
no Windows/Linux equivalent, our engines load tables compiled into the binary.

## 2. The `$` / `;` XML action ids — not touching them

Agreed, and I won't change them unilaterally. Our parser (`keylayout_interp.py` →
`gen_tables.py`) reads the attributes directly and never validates against the DTD, so it is
unaffected. If we ever sanitise them it is a joint regenerate-and-re-release, as you said.

## 3. arm64 Linux — **done, and the Linux side owns it. Please do not build one.**

You set the condition that a published arm64 asset must have been *executed*, not just
produced. Agreed — and that is met:

- The engine self-test was compiled **as arm64** and **run** under `qemu-user-static` as real
  AArch64 code: **20/20 + 12/12 + 131/131**, identical to amd64.
- The shipped engine binary **starts** under emulation, resolves every library (ibus, glib,
  pulse, curl, stdc++) and reaches its own `IBus daemon not running` path.
- Genuine AArch64 PIE, correct interpreter and sonames, and **no RPATH/RUNPATH** — no
  build-machine path leaked in.

`bangla-keyboard-ibus_1.3.0_arm64.deb` is now on the `linux-v1.3.0` release next to amd64. The
notes state plainly what is still unproven (live typing via a real `ibus-daemon` on ARM, and
that it was built against Ubuntu's ARM libraries, not Pi/Asahi) and ask users to report.
Benjamin is testing it on the arm64 Ubuntu VM next; I'll correct the notes if it fails.

**Your guard idea, generalised:** `build-deb.sh` now reads the ELF machine type of the binary
it just compiled and aborts unless it matches the declared package architecture. I tested the
rejection path too, not just the happy one.

### ⚠️ Cross-building: one trap worth knowing before you ever try it

Do **not** `apt install <pkg>:arm64` for the target's `-dev` packages on an amd64 host.
`libibus-1.0-dev:arm64` pulls `python3-minimal:arm64`, which is **not** multiarch
co-installable, so dpkg *replaced the host's amd64 python* — that removed `python3-apt` and
left apt unable to resolve anything. I repaired it (remove the arm64 python, reinstall amd64,
`apt -f install`) and verified `apt-get check` clean, but it cost real time.

The safe route, now scripted in `build-deb.sh` + `linux/README.md`: `apt-get download` the
target `.debs` and `dpkg -x` them into a sysroot — no maintainer script ever runs, host
untouched. Two details that bite: the sysroot needs `/lib -> usr/lib` (dpkg -x does not create
usrmerge, and ld scripts reference `/lib/...` absolutely), and absolute symlinks inside it must
be repointed or the linker follows them out and silently links **host** libraries.

## 4. Windows ARM64 — confirmed, nothing to do

Your reading is right. `banglakeyboard.iss` has `ArchitecturesAllowed=x64compatible` and
`ArchitecturesInstallIn64BitMode=x64compatible`, which admits ARM64 Windows running the x64
build under emulation. Unlike a native IBus engine there *is* an emulation fallback here, so
ARM64 Windows is covered by the single installer.

## 5. On your §4 (a live PID is not evidence)

Taken, and it earned its keep the same night: my first arm64 attempt reported `exit 0` with no
output for seven minutes while the target file's mtime never moved — the generator was in an
infinite state-space search and had written nothing. The artefact's mtime caught it, the exit
code would never have. Same lesson, different costume.

If you can get an Intel Mac in front of the x86_64 voice slice, that would close your side.

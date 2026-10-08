# Toolchain and Build System

## Selected toolchain

**ca65** (macro assembler) and **ld65** (linker) from the
[cc65](https://cc65.github.io/) suite.

Verified version: `ca65 V2.19 - Git 71746c8` / `ld65 V2.19 - Git 71746c8`
(official Windows snapshot `cc65-snapshot-win64.zip`, SHA256
`09C234C5D75EBDB21C77367102C097E5012DE6F9B8C456E724A6BDE4F3B1DBAD`,
downloaded 2026-10-08).

Only the assembler and linker are used. The cc65 C compiler, the C
runtime and `c64.lib` are **not** used; the project ships its own
linker configuration.

## Why ca65/ld65

The project references (`docs/reference/`) do not prescribe a specific
assembler. The 6502 Assembly Language Programming book notes that
assemblers differ in directives and conventions and that the reader
must follow their assembler's manual (pp. 66-69). The choice was
therefore made on project requirements:

| Requirement (from `roadmap.md` / project guidelines) | How ca65/ld65 meets it |
|---|---|
| Reusable library, public API separate from internals (Milestone 6: "Separate public/private symbols", "Hide ACIA implementation") | Separate object modules; only `.export`ed symbols are visible to other modules. `.proc`/`.scope` give local scopes. |
| Low-level hardware access separate from public API (guideline 3) | ACIA driver, protocol layer and API can be separate `.s` files linked together. `ar65` can package them as a `.lib` for games. |
| Integration into existing games (Milestones 9-10) | Linker config controls exactly where code/data go (custom `MEMORY`/`SEGMENTS`), so the library can be relocated to fit a game's free memory. |
| Reproducible command-line build | Non-interactive CLI tools, available for Windows, Linux and macOS. |
| Simple, testable 6502 code (guideline 5) | Label/map/listing output (`-Ln`, `-m`, `-l`) for inspection; `--cpu 6502` restricts to documented NMOS opcodes. |
| Named constants, not magic numbers | Full expression evaluation, including link-time expressions and `.assert`. |

Alternatives considered:

- **ACME**, **64tass**: good single-pass/multi-pass assemblers that emit
  `.prg` directly, but they assemble one monolithic source; there is no
  linker or object-module symbol visibility, which works against the
  library/API separation the roadmap requires.
- **KickAssembler**: powerful scripting, but requires a Java runtime and
  is also monolithic (no object linking).

## Build commands

Windows (PowerShell 5.1+ or PowerShell 7):

```powershell
.\build.ps1 bootstrap    # once: download cc65 into tools\cc65 (git-ignored)
.\build.ps1 verify       # build + structural check of every .prg
.\build.ps1              # build only
.\build.ps1 clean
```

If execution policy blocks scripts, use
`powershell -ExecutionPolicy Bypass -File .\build.ps1 verify`.

Linux/macOS/MSYS2 (cc65 installed, e.g. `apt install cc65`):

```sh
make
make clean
pwsh ./build.ps1 verify   # optional, needs PowerShell 7
```

Toolchain lookup order in `build.ps1`: `$env:CC65_HOME\bin`,
`tools\cc65\bin`, then `PATH`. The Makefile uses `CC65_HOME/bin` if set,
otherwise `PATH`.

## Layout

```
cfg/c64-prg.cfg          ld65 linker configuration (PRG at $0801)
src/include/c64.inc      stock C64 constants (no C64U-specific items)
src/common/basic_stub.s  load address + "10 SYS <start>" BASIC line
src/hello/hello.s        Milestone 0 minimal program
src/include/c64u.inc     C64U ACIA/modem constants (internal, layer 3)
src/c64u/acia.s          C64U communication layer: ACIA access
src/c64u/modem.s         C64U communication layer: dial/answer/hang up
src/tests/commtest.s     Milestone 1 two-machine test program
tools/sim/               logic simulation of commtest (Python, py65)
build/                   output (git-ignored): *.prg, *.map, *.lbl, obj/
```

Each program exports `start`; `basic_stub.s` imports it and the linker
writes its decimal address into the `SYS` line.

Programs and their source lists are defined in two places that must be
kept in sync: `$Programs` in `build.ps1` and `PROGRAMS` / `<name>_SRC`
in the `Makefile`. Objects are named `<program>-<source basename>.o`.
Both builds were checked to produce byte-identical `.prg` files.

## Memory layout (`cfg/c64-prg.cfg`)

| Segment | Placement |
|---|---|
| `LOADADDR` | 2 bytes written at the start of the file (`$01 $08`) |
| `EXEHDR` | BASIC stub at `$0801` |
| `CODE`, `RODATA`, `DATA` | follow the stub |
| `BSS` | after `DATA`, not stored in the file |

The program must end below `$A000`. Staying below the BASIC ROM is
standard C64 memory-map knowledge that **is not yet confirmed by a
project reference**.

## Verification performed by `build.ps1 verify`

For every `build/*.prg`:

1. Load address is `$0801`.
2. First BASIC line contains the `SYS` token (`$9E`) followed by decimal digits.
3. The line-link pointer points to the byte after the line terminator.
4. A two-zero-byte end-of-program marker follows.
5. The `SYS` address equals the `start` symbol in the linker label file
   and lies inside the loaded image.

This is a static check only; it does not execute the program.

## Facts and their sources

| Fact | Source |
|---|---|
| `CHROUT` = `$FFD2` (KERNAL character output) | 6502 Assembly Language Programming, pp. 98-99, 111 |
| A `.prg` runs from the C64U Disk File Browser: the C64U resets, copies the program into memory and runs it | C64U User Guide, "Using PRG and T64 Files", p. 27 |
| `.prg` = 2-byte little-endian load address + memory image | Standard Commodore format; **not stated in project references** |
| BASIC line format, `SYS` token `$9E`, BASIC start `$0801` | Standard C64 BASIC V2; **not stated in project references** (C64 BASIC reference not yet added) |
| PETSCII `$93` clear screen, `$0D` return | Standard PETSCII; **not stated in project references** |
| CHROUT register preservation | **Not documented** in project references; code assumes A, X, Y are clobbered |
| `GETIN` = `$FFE4`, returns 0 if no key | 6502 Assembly Language Programming, p. 93 |
| `GETIN` uses X and Y | 6502 Assembly Language Programming, p. 104 |
| PETSCII `$14` DEL | Standard PETSCII; **not stated in project references** |
| C64U ACIA/modem facts | See `docs/c64u-communication.md` (C64U User Guide ch. 12 + cited external sources) |

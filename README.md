# C64U GameNet

A small 6502 assembly **multiplayer API/library for C64 games** on
**Commodore 64 Ultimate** systems. The long-term goal is multiplayer
adaptations of existing C64 games running on separate C64 Ultimate
machines.

GameNet is not a networking stack: it does not implement TCP/IP or
Wi-Fi. The C64 Ultimate provides the networking; GameNet reaches it
internally through the C64U's documented 6551 ACIA / SwiftLink modem
emulation (C64U User Guide, p. 157). Games only use the GameNet API:

```
C64 game -> GameNet multiplayer API -> GameNet implementation
         -> C64U communication interface (6551/SwiftLink, internal)
         -> C64 Ultimate networking (provided by the C64U)
```

See [`docs/architecture.md`](docs/architecture.md).

## Status

**Milestone 0 — Project Foundation** is complete: toolchain, build
system and a minimal C64 program.

**Milestone 1 — C64 Ultimate Communication Layer** is implemented but
**not yet verified on real hardware**: the internal 6551/modem layer
(`src/c64u/`) and a two-machine test program (`build/commtest.prg`)
build, and the test logic passes a simulation, but no two physical
C64 Ultimate systems have exchanged bytes yet. See
[`roadmap.md`](roadmap.md).

## Requirements

- [cc65](https://cc65.github.io/) suite: only `ca65` (assembler) and
  `ld65` (linker) are used. Tested with V2.19 (Git 71746c8).
- Windows: PowerShell 5.1+ (built in). `curl.exe`/`tar.exe` (built into
  Windows 10/11) for the optional toolchain bootstrap.
- Linux/macOS: GNU Make and cc65 (e.g. `apt install cc65`,
  `brew install cc65`).

## Building

Windows:

```powershell
.\build.ps1 bootstrap   # first time only: downloads cc65 into tools\cc65
.\build.ps1 verify      # builds build\hello.prg + build\commtest.prg, checks structure
```

Other targets: `.\build.ps1 build` (default), `.\build.ps1 clean`,
`.\build.ps1 toolchain`. If scripts are blocked, run
`powershell -ExecutionPolicy Bypass -File .\build.ps1 verify`.

Linux/macOS:

```sh
make            # -> build/hello.prg, build/commtest.prg
make clean
```

If cc65 is installed elsewhere, set `CC65_HOME` to its root directory.

## Running

`build/hello.prg` is a standard C64 program loaded at `$0801` with a
`10 SYS 2061` BASIC line. It clears the screen, prints

```
C64U GAMENET
MILESTONE 0 TOOLCHAIN OK
```

and returns to the `READY.` prompt.

On a C64 Ultimate: copy the file to USB storage or the SD card (or
upload it via the C64U FTP File Service), open the Disk File Browser,
select the file and run it (C64U User Guide, "Using PRG and T64 Files").
If written to a disk image as `HELLO`, it can be started with
`LOAD"HELLO",8` followed by `RUN`. It can also be run in any C64
emulator.

`build/commtest.prg` is the Milestone 1 two-machine test. It requires
two C64 Ultimate systems with modem emulation enabled; follow
[`docs/milestone1-hardware-test.md`](docs/milestone1-hardware-test.md).
It cannot be meaningfully run in a normal C64 emulator.

Optional logic simulation of the test (not hardware verification;
needs Python 3 and `pip install py65`):

```sh
python tools/sim/commtest_sim.py
```

## Repository layout

```
cfg/            ld65 linker configurations
src/include/    shared include files (constants)
src/common/     modules shared by all programs (BASIC stub)
src/hello/      Milestone 0 minimal program
src/c64u/       internal C64U communication layer (6551 ACIA, modem)
src/tests/      test programs (Milestone 1 two-machine test)
tools/sim/      logic simulation of the two-machine test (Python/py65)
docs/           project documentation
docs/reference/ reference material (C64U User Guide, 6502 book)
build.ps1       Windows/PowerShell build script
Makefile        GNU Make build
build/          build output (git-ignored)
tools/cc65/     locally bootstrapped toolchain (git-ignored)
```

## Documentation

- [`docs/toolchain.md`](docs/toolchain.md) — assembler choice,
  build system, memory layout, sources of hardware facts.
- [`docs/architecture.md`](docs/architecture.md) — layers and
  responsibilities (API, implementation, C64U interface, C64U networking).
- [`docs/c64u-communication.md`](docs/c64u-communication.md) — C64U
  configuration, register mapping, internal layer API, open questions.
- [`docs/milestone1-hardware-test.md`](docs/milestone1-hardware-test.md)
  — two-machine test procedure and results record.
- [`roadmap.md`](roadmap.md) — milestones.
- [`CHANGELOG.md`](CHANGELOG.md) — changes.

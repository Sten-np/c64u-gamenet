# C64U GameNet

A 6502 assembly networking library for **Commodore 64 Ultimate**
systems. The long-term goal is to let C64 programs on separate C64
Ultimate machines communicate over a network, enabling multiplayer
adaptations of existing C64 games.

The intended network path is the C64U's documented 6551 ACIA /
SwiftLink modem emulation (C64U User Guide, p. 157), not direct access
to the C64U's network hardware:

```
C64 game -> C64Net API -> connection/protocol -> ACIA/6551 driver
         -> C64 Ultimate modem emulation -> TCP/network
```

## Status

**Milestone 0 — Project Foundation** is complete: toolchain, build
system and a minimal C64 program. No networking code exists yet. See
[`roadmap.md`](roadmap.md) for the plan.

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
.\build.ps1 verify      # builds build\hello.prg and checks its structure
```

Other targets: `.\build.ps1 build` (default), `.\build.ps1 clean`,
`.\build.ps1 toolchain`. If scripts are blocked, run
`powershell -ExecutionPolicy Bypass -File .\build.ps1 verify`.

Linux/macOS:

```sh
make            # -> build/hello.prg
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

## Repository layout

```
cfg/            ld65 linker configurations
src/include/    shared include files (constants)
src/common/     modules shared by all programs (BASIC stub)
src/hello/      Milestone 0 minimal program
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
- [`roadmap.md`](roadmap.md) — milestones.
- [`CHANGELOG.md`](CHANGELOG.md) — changes.

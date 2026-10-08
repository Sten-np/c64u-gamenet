# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added — Milestone 1: C64 Ultimate Communication Layer (not yet hardware-verified)

- `docs/c64u-communication.md`: C64U modem configuration (`DE00/NMI`,
  SwiftLink, listening port, RING/ATA), AT commands, incoming-call
  states and banner, register mapping, internal layer API, resource
  and cycle notes, emulator limitations, 12 open questions. Every
  hardware fact is tagged with its source (C64U User Guide pages;
  external WDC W65C51N datasheet, Ultimate firmware docs, COMPUTE!
  #10 clearly marked as external).
- `src/include/c64u.inc`: named ACIA addresses/bits and modem
  constants (C64U-specific, internal).
- `src/c64u/acia.s`: `c64u_init`, `c64u_status`, `c64u_send`,
  `c64u_receive`, `c64u_shutdown` — polled, ACIA interrupts disabled,
  no zero page, 1 byte RAM.
- `src/c64u/modem.s`: `c64u_delay`, `c64u_send_string`,
  `c64u_modem_dial` (`ATDT`), `c64u_modem_answer` (`ATA`),
  `c64u_modem_hangup` (`+++`, `ATH`) — no zero page, 1 byte RAM.
- `src/tests/commtest.s` → `build/commtest.prg`: two-machine test
  (caller/answerer, sync markers that skip modem text and banner,
  `$00..$FF` A→B and `$FF..$00` B→A, verification, verdict exchange,
  on-screen status/values/PASS-FAIL, hang-up).
- `docs/milestone1-hardware-test.md`: physical two-C64U test procedure
  and empty results record.
- `tools/sim/commtest_sim.py`: logic simulation of the test on two
  py65 CPUs with a modem model (not hardware verification).
- `GETIN` and `PETSCII_DEL` in `src/include/c64.inc`.

### Changed

- `build.ps1` and `Makefile` build `commtest.prg`; the `Makefile` now
  supports sources from any directory and was verified (via WSL) to
  produce byte-identical output to `build.ps1`.
- `roadmap.md`: Milestone 1 status "implemented, not yet verified on
  hardware" with verification table. `README.md`,
  `docs/architecture.md`, `docs/toolchain.md` updated.

### Changed — Project scope clarification

- GameNet is now defined as a multiplayer API/library for C64 games,
  not a networking stack; the C64 Ultimate provides the networking.
- `roadmap.md` restructured: Milestone 1 is now the internal C64U
  communication layer (two-machine byte exchange), followed by message
  layer, background reception, game-facing API (names not finalized),
  test application, synchronization, reverse engineering and first
  game. Added open questions not answered by the C64U User Guide and
  an explicit out-of-scope list.
- Added `docs/architecture.md` separating the game-facing API, GameNet
  implementation, C64U communication interface and C64U networking.
- `README.md` updated to the new scope.

### Added — Milestone 0: Project Foundation

- Selected the ca65/ld65 assembler and linker (cc65 suite, V2.19) as the
  project toolchain; rationale in `docs/toolchain.md`.
- Project structure: `cfg/`, `src/include/`, `src/common/`, `src/hello/`,
  `docs/`.
- `cfg/c64-prg.cfg`: ld65 configuration producing a standard `.prg`
  loaded at `$0801` (no cc65 C runtime).
- `src/include/c64.inc`: stock C64 constants (`CHROUT`, BASIC, PETSCII).
- `src/common/basic_stub.s`: PRG load address and `10 SYS <start>` BASIC
  line; the SYS address is computed by the linker.
- `src/hello/hello.s`: minimal program that prints a banner and returns
  to BASIC.
- `build.ps1`: Windows/PowerShell build with `build`, `verify`, `clean`,
  `bootstrap` (downloads cc65 into `tools/cc65`) and `toolchain` targets.
  `verify` structurally checks every generated `.prg`.
- `Makefile`: GNU Make build for Linux/macOS/MSYS2.
- `.gitignore`, `README.md`, `CHANGELOG.md`, `docs/toolchain.md`.

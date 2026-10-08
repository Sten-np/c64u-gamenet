# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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

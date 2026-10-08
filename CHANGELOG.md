# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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

---
name: c64-6502-development
description: Use when working on Commodore 64, 6502 assembly, C64 Ultimate hardware, memory-mapped hardware, KERNAL/BASIC interaction, or C64 networking in this project.
---

# C64 / 6502 Development

## References

Before making hardware-specific claims or implementing hardware-facing
code, consult the relevant files under `docs/reference/`.

Primary references currently included:

- `docs/reference/c64u-user-guide-1st-edition.pdf`
- `docs/reference/6502-assembly-language-programming-for-apple-commodore-and-atari-computers.pdf`

Use the C64 Ultimate guide as the primary source for C64U-specific
features such as modem/SwiftLink/6551 behavior.

Use the 6502 assembly book for CPU and assembly-language concepts.

## Hardware discipline

- Distinguish CPU behavior from C64 hardware behavior.
- Distinguish original C64 behavior from C64 Ultimate additions.
- Do not assume that a documented C64U feature exists on an original C64.
- Do not reverse-engineer undocumented C64U internals when a documented
  interface is available.
- Record important memory addresses and register meanings in project
  documentation.

## Assembly discipline

- Prefer labels and named constants over unexplained magic numbers.
- Keep public API symbols separate from internal implementation symbols.
- Comment non-obvious register usage and calling conventions.
- Preserve registers deliberately and document when a routine changes them.
- Keep routines small enough to test independently.

## Networking discipline

The project's intended C64U networking path is the documented
C64U modem/6551/SwiftLink interface rather than direct access to the
C64U Wi-Fi hardware.

Keep the following conceptual layers separate:

C64 game
→ C64Net API
→ connection/protocol layer
→ ACIA/6551 driver
→ C64 Ultimate modem emulation
→ TCP/network

Do not implement TCP/IP inside the C64 assembly library unless a later
roadmap decision explicitly requires it.

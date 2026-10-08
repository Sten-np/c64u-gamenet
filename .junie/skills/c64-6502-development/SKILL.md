---
name: c64-6502-development
description: Use when working on Commodore 64, 6502 assembly, C64 Ultimate hardware, memory-mapped hardware, KERNAL/BASIC interaction, the C64U communication layer (6551/SwiftLink), or the GameNet multiplayer API in this project.
---

# C64 / 6502 Development for C64U GameNet

## Project scope

C64U GameNet is a **multiplayer-enablement library/API for existing
Commodore 64 games**. It lets reverse-engineered or modified C64 games
replace or extend local multiplayer with networked multiplayer between
separate C64 Ultimate systems.

GameNet is **game-oriented, not network-oriented**. It is not a
networking stack. The C64 Ultimate already provides the underlying
networking; GameNet only uses the C64U's documented communication
interface to reach it.

Before substantial work, read `roadmap.md` and `docs/architecture.md`.
`roadmap.md` is the milestone source of truth.

## Architecture boundaries

Keep these layers separate. Each layer talks only to the layer
directly below it:

```text
Existing/modified C64 game
          |
          v
   GameNet public API            <- public, game-facing (GameNet)
          |
          v
   GameNet implementation        <- internal (GameNet)
          |
          v
C64U communication layer         <- internal transport (GameNet)
   (6551 ACIA / SwiftLink)
          |
          v
C64 Ultimate networking          <- provided by the C64U, not GameNet
          |
          v
   Other C64 Ultimate
          |
          v
   Other C64 game
```

### Public API

- Expose a small API suitable for old C64 games: little memory, few
  cycles, simple register-based calling conventions, no dependence on
  the game giving up its own memory layout or interrupt setup beyond
  what is documented.
- Never expose TCP/IP, IP addresses, ports, Wi-Fi, Ethernet, Telnet,
  AT/modem commands or ACIA registers to game code. The game deals
  only in multiplayer concepts (start, connect, send, receive, status,
  disconnect).
- The public API is **not finalized**. Names such as `gamenet_init`,
  `gamenet_connect`, `gamenet_disconnect`, `gamenet_send`,
  `gamenet_receive` and `gamenet_status` are working names only. Do
  not design or freeze the final API outside the roadmap milestone
  that covers it.

### Game-agnostic rule

- GameNet must remain game-agnostic. It must not contain concepts
  specific to any game (for example Bubble Bobble players, enemies,
  levels, bubbles, collision rules, scores).
- Different games may use GameNet differently (input exchange, state
  exchange, events, or other data).
- The game adaptation — not GameNet — decides what game state, input,
  events or other data need to be exchanged, and how often.
- GameNet transports game-defined data; it does not interpret it.

### Internal transport

- The 6551 ACIA / SwiftLink interface is an internal implementation
  detail of the C64U communication layer. Only that layer touches
  communication hardware registers or sends modem commands.
- The C64 Ultimate is responsible for the actual networking.
- GameNet does not implement TCP/IP, UDP, Wi-Fi, Ethernet, DNS,
  Telnet, routing, retransmission or any general networking protocol,
  and does not access C64U network hardware directly.
- Do not add networking infrastructure (servers, discovery, protocol
  stacks) that the roadmap does not call for.

## Current milestone

The current milestone is the internal **C64 Ultimate Communication
Layer** (roadmap Milestone 1): prove that two C64 Ultimate systems can
exchange bytes through the C64U's modem emulation. Work on one
milestone at a time and do not start later milestones unless
explicitly requested.

## References

Before making hardware-specific claims or implementing hardware-facing
code, consult the relevant files under `docs/reference/`:

- `docs/reference/c64u-user-guide-1st-edition.pdf` — primary source
  for C64U-specific behavior: networking (chapter 11) and modem
  emulation, 6551/SwiftLink mapping and supported AT commands
  (chapter 12).
- `docs/reference/6502-assembly-language-programming-for-apple-commodore-and-atari-computers.pdf`
  — CPU and assembly-language concepts.

## Reference-document discipline

- Verify C64U-specific hardware behavior against the project
  reference documentation; do not guess or substitute generic model
  knowledge.
- Cite the source (document and page or chapter) for hardware facts
  recorded in project documentation.
- Clearly distinguish **documented facts** from **assumptions that
  still require hardware verification**. Label unverified items as
  such (see the "Open questions" in `roadmap.md`).
- When the references do not establish an answer, say so and state
  what needs to be verified on real hardware or from an additional,
  explicitly cited reference.
- Record verified hardware results in project documentation.

## Hardware discipline

- Distinguish CPU behavior from C64 hardware behavior.
- Distinguish original C64 behavior from C64 Ultimate additions.
- Do not assume that a documented C64U feature exists on an original C64.
- Do not reverse-engineer undocumented C64U internals when a documented
  interface is available.
- Record important memory addresses and register meanings in project
  documentation, with their source.
- Keep low-level hardware access separate from the public API.

## Assembly discipline

- Prefer labels and named constants over unexplained magic numbers.
- Keep public API symbols separate from internal implementation symbols.
- Comment non-obvious register usage and calling conventions.
- Preserve registers deliberately and document when a routine changes them.
- Keep routines small enough to test independently.
- Be mindful of the host game: minimize zero-page, memory, cycle and
  interrupt usage, and document every resource GameNet requires.
- Verify generated binaries/build artifacts whenever possible.

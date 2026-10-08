# C64U GameNet Roadmap

## Project Goal

C64U GameNet is a small **multiplayer API/library for C64 games**
running on Commodore 64 Ultimate systems.

The long-term goal is to let existing C64 games be adapted for
multiplayer play between separate C64 Ultimate machines, with the game
using a small, simple API and never dealing with networking details.

## Scope

GameNet is **not** a networking stack. The C64 Ultimate already
provides the networking (Ethernet/Wi-Fi, TCP, Telnet modem emulation —
C64U User Guide, chapters 11 and 12). GameNet sits on top of it:

```text
C64 multiplayer game
        |
        v
C64U GameNet multiplayer API        <- public, game-facing (GameNet)
        |
        v
GameNet implementation              <- internal (GameNet)
        |
        v
C64 Ultimate communication layer    <- internal transport (GameNet)
  (6551 ACIA / SwiftLink emulation)
        |
        v
C64 Ultimate networking             <- provided by the C64U, not GameNet
        |
        v
Other C64U -> other game
```

GameNet does **not** implement TCP/IP, Wi-Fi, Ethernet, DNS, Telnet or
any other network protocol. The 6551/SwiftLink interface is an
internal transport detail that games never see. See
[`docs/architecture.md`](docs/architecture.md) for the layer
responsibilities.

---

## Milestone 0 — Project Foundation

**Status:** ✅ Complete (build verified on Windows; real C64 Ultimate run pending — see notes)

Establish a reproducible 6502 development environment.

### Tasks

- [x] Establish project structure
- [x] Select 6502 assembler/toolchain — ca65/ld65 (cc65 V2.19)
- [x] Document assembler choice — `docs/toolchain.md`
- [x] Create build system — `build.ps1` (Windows), `Makefile` (GNU Make)
- [x] Create minimal C64 program — `src/hello/hello.s`
- [x] Produce a valid `.prg` — `build/hello.prg`
- [x] Verify build process — `.\build.ps1 verify` (static structure check)
- [x] Create initial documentation — `README.md`, `docs/toolchain.md`
- [x] Create `.gitignore`
- [x] Create `CHANGELOG.md`

### Notes

- `build/hello.prg` has not yet been run on a real C64 Ultimate or an
  emulator; `verify` checks file structure only.
- The `Makefile` has not yet been exercised (GNU Make was not available
  on the development machine).

### Completion criteria

A clean checkout of the repository can be built from the command line and produces a valid C64 `.prg` file.

---

## Milestone 1 — C64 Ultimate Communication Layer

**Status:** 🔲 Not started — next implementation milestone

Prove that GameNet can exchange bytes and simple test messages
between **two C64 Ultimate systems**, using the C64U's documented
modem emulation (6551 ACIA, SwiftLink mode, `DE00/NMI` mapping —
C64U User Guide, p. 157) as an internal transport.

This layer is internal. It is not the game-facing API, and it does not
implement any networking: the C64U carries the bytes over its own
network connection.

### Tasks

- [ ] Document the communication interface as established by the
      C64U User Guide (mapping, hardware mode, supported AT commands,
      incoming-connection behaviour) — `docs/c64u-communication.md`
- [ ] Identify and list facts the C64U User Guide does **not**
      establish (see "Open questions" below) and how each is verified
- [ ] Document the required C64U configuration for both machines
      (modem enabled, `DE00/NMI`, SwiftLink, listening port)
- [ ] Define named constants for the communication interface
- [ ] Implement initialization of the communication interface
- [ ] Implement status reading (data available / ready to send)
- [ ] Implement polled byte send and byte receive
- [ ] Implement the minimal modem command handling needed for one
      C64U to call the other (`ATDT host:port`) and for the other to
      answer (`RING` / `ATA`), and to hang up (`ATH`)
- [ ] Handle the banner text the C64U sends to the calling side
      before the connection carries program data (p. 160)
- [ ] Create a two-machine test program (one side calls, one side
      answers; send a known byte pattern in both directions; verify
      and report errors on screen)
- [ ] Test on two real C64 Ultimate systems
- [ ] Record test results and any verified hardware behaviour

### Open questions requiring verification

The C64U User Guide does not establish these; they must be answered
by testing on real hardware or by an additional, explicitly cited
reference before being relied on:

- The 6551 register layout and bit meanings as emulated by the C64U
  (the guide only names the chip and the `DE00` mapping).
- Supported baud-rate settings and their effect (the guide only shows
  19200 as an example CCGMS setting).
- Whether all 256 byte values pass through the connection unchanged
  (the C64U describes the link as Telnet; binary transparency is not
  documented).
- Whether the `+++` escape sequence can be triggered accidentally by
  game data, and how to avoid it (the guide documents `S2`/`S12`).
- How connection state (connected / hung up) can be detected from the
  C64 side.
- Whether NMIs are generated on receive and how they must be
  acknowledged (only the `DE00/NMI` mapping name is documented).

### Completion criteria

Two C64 Ultimate systems, configured as documented, can establish a
connection through the C64U modem emulation and reliably exchange
bytes in both directions, as demonstrated by the test program.

---

## Milestone 2 — GameNet Message Layer (internal)

**Status:** 🔲 Not started

Turn the byte stream from Milestone 1 into small, discrete messages
suitable for games. Kept deliberately minimal; the C64U connection
already delivers bytes in order, so GameNet does not add its own
retransmission or routing.

### Tasks

- [ ] Define a compact message framing (e.g. type + length + payload)
- [ ] Define maximum message size
- [ ] Implement message encoding and decoding
- [ ] Implement validation and malformed-message handling
- [ ] Implement resynchronization after a framing error
- [ ] Document the message format
- [ ] Test between two C64 Ultimate systems

### Completion criteria

Two C64 Ultimate systems can exchange structured messages, and
malformed input is detected without crashing or hanging.

---

## Milestone 3 — Background Reception

**Status:** 🔲 Not started

Let games receive data without polling the communication interface in
their main loop.

### Tasks

- [ ] Verify C64U NMI behaviour for the `DE00/NMI` mapping
- [ ] Implement interrupt-driven reception into a receive buffer
- [ ] Handle buffer overflow
- [ ] Make reception non-blocking
- [ ] Measure CPU cost
- [ ] Test under game-like CPU load (raster/IRQ-heavy program)

### Completion criteria

Incoming data is buffered in the background, and a game-like main
loop can consume it without missing data or polling the hardware.

---

## Milestone 4 — Game-Facing Multiplayer API

**Status:** 🔲 Not started

Define and implement the public API that games use. The exact API is
**not finalized**; it will be designed in this milestone based on what
Milestones 1–3 established. Conceptually it is expected to cover:

- initialization (`gamenet_init`)
- connecting to / accepting another player (`gamenet_connect`)
- disconnecting (`gamenet_disconnect`)
- sending a message (`gamenet_send`)
- receiving a message (`gamenet_receive`)
- querying connection status (`gamenet_status`)

These names are working names only.

### Tasks

- [ ] Design the API (routines, calling conventions, register usage,
      status/error codes)
- [ ] Decide how a game expresses "host" vs "join" without knowing
      about modem commands or addresses
- [ ] Decide how connection settings (e.g. the other C64U's address)
      are provided
- [ ] Implement the API on top of the internal layers
- [ ] Separate public and internal symbols
- [ ] Document the API — `docs/api.md`
- [ ] Create a small example program using only the public API

### Completion criteria

A C64 program can connect two C64 Ultimate systems and exchange
messages using only the public GameNet API, with no access to the
6551 registers, AT commands or network details.

---

## Milestone 5 — Multiplayer Test Application

**Status:** 🔲 Not started

Create a minimal multiplayer demonstration using only the public API.

### Goal

Two C64 Ultimate systems each control a player.

```text
C64U A                    C64U B

  @                         @
  |                         |
  +------ GameNet ----------+
```

### Tasks

- [ ] Implement local player
- [ ] Implement remote player
- [ ] Send player input
- [ ] Send player position
- [ ] Render remote player
- [ ] Handle disconnect
- [ ] Measure latency

### Completion criteria

Two C64 Ultimate systems can control separate players in the same program.

---

## Milestone 6 — Game Synchronization Support

**Status:** 🔲 Not started

Investigate and, where useful, provide simple helpers for keeping two
copies of a game consistent. This concerns game state, not network
protocols.

### Tasks

- [ ] Frame/tick numbering
- [ ] Input-exchange vs. state-exchange strategies
- [ ] Detecting a lost or silent peer (timeouts)
- [ ] Behaviour on disconnect
- [ ] Latency handling
- [ ] Interpolation/prediction investigation

### Completion criteria

The multiplayer test remains stable and consistent on both machines
under realistic conditions.

---

## Milestone 7 — Game Reverse Engineering

**Status:** 🔲 Not started

Develop a repeatable process for adapting existing C64 games.

### Tasks

- [ ] Select first target game
- [ ] Identify program layout
- [ ] Identify game loop
- [ ] Identify input handling
- [ ] Identify player state
- [ ] Identify player position
- [ ] Identify collision state
- [ ] Identify relevant game state
- [ ] Document memory addresses
- [ ] Identify suitable synchronization points
- [ ] Identify memory available for GameNet

### Completion criteria

The target game's relevant internal state is understood well enough to begin multiplayer modification.

---

## Milestone 8 — First Multiplayer Game

**Status:** 🔲 Not started

Adapt the first existing C64 game for multiplayer using GameNet.

### Tasks

- [ ] Integrate GameNet
- [ ] Synchronize players
- [ ] Synchronize required game state
- [ ] Preserve original gameplay
- [ ] Test two C64 Ultimate systems
- [ ] Fix synchronization issues
- [ ] Document modifications

### Completion criteria

The selected C64 game can be played multiplayer across two C64 Ultimate systems.

---

## Long-Term Ideas

These are deliberately outside the initial milestones.

- [ ] More than two players
- [ ] Simple lobby / player matching
- [ ] Spectator mode
- [ ] Debugging aids for GameNet messages (on the C64 or a PC)

## Out of Scope

GameNet will not provide these; they are the C64 Ultimate's
responsibility or unrelated to a game-facing multiplayer API:

- TCP/IP, UDP, DNS or any other network protocol implementation
- Wi-Fi or Ethernet configuration or drivers
- Direct access to the C64U network hardware
- Router, firewall or Internet-access configuration
- General-purpose terminal, BBS or file-transfer functionality

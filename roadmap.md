# C64U GameNet Roadmap

## Project Goal

C64U GameNet is a reusable networking library for Commodore 64
Ultimate systems.

The long-term goal is to allow C64 programs running on separate
C64 Ultimate systems to communicate over a network and enable
multiplayer adaptations of existing C64 games.

---

## Milestone 0 — Project Foundation

**Status:** 🔲 Not started

Establish a reproducible 6502 development environment.

### Tasks

- [ ] Establish project structure
- [ ] Select 6502 assembler/toolchain
- [ ] Document assembler choice
- [ ] Create build system
- [ ] Create minimal C64 program
- [ ] Produce a valid `.prg`
- [ ] Verify build process
- [ ] Create initial documentation
- [ ] Create `.gitignore`
- [ ] Create `CHANGELOG.md`

### Completion criteria

A clean checkout of the repository can be built from the command line and produces a valid C64 `.prg` file.

---

## Milestone 1 — 6551 ACIA Driver

**Status:** 🔲 Not started

Implement the low-level interface to the C64 Ultimate's 6551/SwiftLink modem emulation.

### Tasks

- [ ] Document 6551 register layout
- [ ] Document C64U memory mapping
- [ ] Define ACIA constants
- [ ] Implement ACIA initialization
- [ ] Implement status reading
- [ ] Implement byte transmission
- [ ] Implement byte reception
- [ ] Create ACIA test program
- [ ] Test on real C64 Ultimate

### Completion criteria

A C64 program can reliably transmit and receive bytes through the C64U's 6551/SwiftLink interface.

---

## Milestone 2 — Connection Management

**Status:** 🔲 Not started

Create a higher-level connection abstraction.

### Tasks

- [ ] Initialize networking
- [ ] Connect to remote endpoint
- [ ] Detect connection state
- [ ] Disconnect
- [ ] Handle connection errors
- [ ] Document connection API

### Completion criteria

A C64 program can establish and terminate a network connection through the C64 Ultimate modem interface.

---

## Milestone 3 — C64U-to-C64U Communication

**Status:** 🔲 Not started

Establish communication between two physical C64 Ultimate systems.

### Tasks

- [ ] Configure C64U A
- [ ] Configure C64U B
- [ ] Establish TCP connection
- [ ] Implement HELLO message
- [ ] Implement response
- [ ] Implement PING
- [ ] Implement PONG
- [ ] Measure communication latency
- [ ] Test connection failure handling

### Completion criteria

Two C64 Ultimate systems can reliably exchange messages.

---

## Milestone 4 — Binary Protocol

**Status:** 🔲 Not started

Create a compact binary protocol suitable for games.

### Tasks

- [ ] Define packet structure
- [ ] Define message types
- [ ] Define packet length
- [ ] Implement packet encoding
- [ ] Implement packet decoding
- [ ] Implement validation
- [ ] Implement malformed-packet handling
- [ ] Document protocol

### Completion criteria

C64 systems can exchange structured binary messages.

---

## Milestone 5 — Interrupt-Driven Networking

**Status:** 🔲 Not started

Move network reception away from continuous polling where practical.

### Tasks

- [ ] Investigate C64U NMI configuration
- [ ] Implement NMI handling
- [ ] Create receive buffer
- [ ] Handle buffer overflow
- [ ] Make receive API non-blocking
- [ ] Test under game-like CPU load

### Completion criteria

Network data can be received without requiring the main game loop to continuously poll the hardware.

---

## Milestone 6 — C64Net Public API

**Status:** 🔲 Not started

Create a clean API that C64 games can use without dealing directly with the ACIA hardware.

Example:

```asm
jsr net_init
jsr net_connect
jsr net_send
jsr net_receive
jsr net_disconnect
```

### Tasks

- [ ] Define public API
- [ ] Separate public/private symbols
- [ ] Hide ACIA implementation
- [ ] Document API
- [ ] Create example application
- [ ] Test API stability

### Completion criteria

A C64 program can use networking without directly accessing the 6551 registers.

---

## Milestone 7 — Multiplayer Test Application

**Status:** 🔲 Not started

Create a minimal multiplayer demonstration.

### Goal

Two C64 Ultimate systems each control a player.

```text
C64U A                    C64U B

  @                         @
  |                         |
  +------ network ----------+
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

## Milestone 8 — Synchronization & Reliability

**Status:** 🔲 Not started

Investigate synchronization strategies appropriate for C64 games.

### Tasks

- [ ] Frame/tick numbering
- [ ] State synchronization
- [ ] Message ordering
- [ ] Connection loss detection
- [ ] Timeout handling
- [ ] Reconnection strategy
- [ ] Latency handling
- [ ] Interpolation/prediction investigation

### Completion criteria

The multiplayer test remains stable under realistic network conditions.

---

## Milestone 9 — Game Reverse Engineering

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
- [ ] Identify suitable network synchronization points

### Completion criteria

The target game's relevant internal state is understood well enough to begin multiplayer modification.

---

## Milestone 10 — First Multiplayer Game

**Status:** 🔲 Not started

Adapt the first existing C64 game for network multiplayer.

### Tasks

- [ ] Integrate C64Net
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
- [ ] Dedicated C64U server
- [ ] Game lobby
- [ ] Automatic discovery on LAN
- [ ] Internet play
- [ ] Spectator mode
- [ ] Network debugging tools
- [ ] Packet analyzer
- [ ] C64Net protocol analyzer for PC
- [ ] Multiplayer game framework

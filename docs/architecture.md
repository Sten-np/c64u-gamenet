# C64U GameNet Architecture

## Purpose

C64U GameNet is a small **multiplayer API/library for C64 games**. It
lets a game running on one Commodore 64 Ultimate exchange game data
with the same (or a compatible) game running on another C64 Ultimate.

GameNet is **not** a networking stack. It does not implement TCP/IP,
Wi-Fi, Ethernet, DNS or Telnet, and it does not replace or bypass the
C64 Ultimate's networking. The C64 Ultimate already provides the
network connection; GameNet only uses the C64U's documented
communication interface to reach it.

## Layers

```text
+--------------------------------------------------------------+
| C64 multiplayer game                                         |
+--------------------------------------------------------------+
        |  public calls only (working names: gamenet_init, ...)
        v
+--------------------------------------------------------------+
| 1. Game-facing multiplayer API              [GameNet, public] |
+--------------------------------------------------------------+
        v
+--------------------------------------------------------------+
| 2. GameNet implementation                 [GameNet, internal] |
|    connection state, messages, receive buffering             |
+--------------------------------------------------------------+
        v
+--------------------------------------------------------------+
| 3. C64 Ultimate communication interface   [GameNet, internal] |
|    6551 ACIA / SwiftLink emulation at DE00, modem commands   |
+--------------------------------------------------------------+
        v  ---------------- C64 / C64U boundary ----------------
+--------------------------------------------------------------+
| 4. C64 Ultimate networking                   [C64U, not ours] |
|    modem emulation, Telnet/TCP, Ethernet / Wi-Fi             |
+--------------------------------------------------------------+
        v
     network  ->  other C64U (layer 4)  ->  layers 3, 2, 1  ->  other game
```

Each layer only talks to the layer directly below it. Only layer 3
touches C64U hardware registers.

### 1. Game-facing multiplayer API (public)

What the game sees. It deals in multiplayer concepts: start GameNet,
connect to the other player, send a message, receive a message, check
status, disconnect.

The API is **not finalized**. Its expected scope, using working names
only, is:

| Working name         | Concept                                     |
|----------------------|---------------------------------------------|
| `gamenet_init`       | prepare GameNet for use                     |
| `gamenet_connect`    | connect to / accept the other player        |
| `gamenet_disconnect` | end the session                             |
| `gamenet_send`       | send a game message                         |
| `gamenet_receive`    | fetch a received game message, if any       |
| `gamenet_status`     | report connection / data state              |

Rules:

- The game never sees 6551 registers, AT commands, IP addresses,
  ports, Telnet, TCP or Wi-Fi.
- Calling conventions, register usage and error codes are documented
  per routine once designed (roadmap Milestone 4).
- Public symbols are the only symbols a game may reference.

### 2. GameNet implementation (internal)

The logic that makes the API work, independent of how bytes travel:

- session/connection state (idle, connecting, connected, lost)
- mapping "host" / "join" onto the communication layer's
  answer / call operations
- message framing on top of the byte stream (roadmap Milestone 2)
- receive buffering, possibly interrupt-driven (roadmap Milestone 3)
- game-level timeouts and synchronization helpers (roadmap Milestone 6)

It does not add networking features the C64U connection already
provides (routing, addressing, retransmission of an in-order byte
stream).

### 3. C64 Ultimate communication interface (internal transport)

The only hardware-facing part of GameNet. It moves bytes between the
C64 and the C64U's modem emulation, and issues the few modem commands
needed to open and close a connection. It is an implementation detail;
it could in principle be replaced without changing layers 1 and 2.

Established by the C64U User Guide (1st edition, chapter 12):

- The C64U emulates the MOS 6551 ACIA, as found in the SwiftLink
  cartridge (p. 157).
- Modem emulation is disabled by default. It is enabled in the C64U
  Menu under "Modems": "ACIA (6551) Mapping" = `DE00/NMI`,
  "Hardware Mode" = `SwiftLink` (p. 157).
- `DE00` may conflict with other C64U features mapped there, such as
  extra SID chips or utility cartridges (p. 158).
- The modem is controlled with a subset of the Hayes AT command set:
  `ATI`, `ATZ`, `ATH`, `ATD` (`ATDT host:port`, default port 80),
  `ATA`, `ATO`, `ATV` (ignored), `ATS` registers (`S0`, `S1`, `S2`,
  `S12`), and the `+++` escape sequence (pp. 158–159).
- The modem emulation can accept incoming connections on a configured
  TCP port (p. 159). Depending on state, the caller receives an
  offline, busy or connect message (from configurable files or a
  default text); in the Ready state the answering side may receive
  `RING` and must answer with `ATA` if "Do RING sequence" is enabled
  (pp. 159–160).
- "Offline" is tied to DTR=0, i.e. the ACIA not being configured by
  C64 software (p. 160).

Not established by the C64U User Guide (must be verified before use —
see roadmap Milestone 1, "Open questions"): the emulated register
layout and bit meanings, baud-rate behaviour, binary transparency of
the connection, NMI generation/acknowledgement, and how connection
state is visible to the C64.

Consequences for GameNet:

- Connecting two C64Us means one side **calls** (`ATDT` with the other
  C64U's address and listening port) and the other **answers**. This
  maps naturally onto a "join" / "host" pair in layer 2.
- The calling side receives the C64U's connect message before any
  program data; layer 3 must handle this.
- Game data must never accidentally form a modem escape sequence.

Compatibility: this layer requires the C64 Ultimate's modem emulation
(or real SwiftLink-compatible hardware plus an equivalent network
modem, which is not a project target). A stock C64 without such a
device cannot use GameNet.

### 4. C64 Ultimate networking (provided by the C64U)

Everything below the emulated 6551 belongs to the C64 Ultimate, not to
GameNet:

- Ethernet / Wi-Fi connection and IP configuration (chapter 11)
- the modem emulation's TCP/Telnet connection handling (chapter 12)
- the listening port, connect/busy/offline message files, RING
  configuration (chapter 12)
- router/firewall setup for connections from outside the local
  network (p. 159; outside the guide's scope and GameNet's)

GameNet only documents the configuration the user must apply on each
C64U; it does not implement or control any of it.

## Responsibilities summary

| Concern                                  | Owner                 |
|------------------------------------------|-----------------------|
| Game logic, what to send and when        | Game                  |
| Multiplayer API, status codes            | GameNet layer 1       |
| Session state, messages, buffering       | GameNet layer 2       |
| 6551 access, modem commands              | GameNet layer 3       |
| TCP, Telnet, Ethernet, Wi-Fi, IP address | C64 Ultimate          |
| C64U menu configuration                  | User (documented by GameNet) |

## Source layout (planned)

Only `src/include`, `src/common` and `src/hello` exist today. The
intended separation, to be introduced with the corresponding
milestones, is:

```text
src/include/   shared constants; public API include for games
src/gamenet/   layer 1 + 2 (public API and internal logic)
src/c64u/      layer 3 (C64U communication interface)
src/tests/     test programs
```

Exact names are decided when each milestone is implemented.

## References

- C64U User Guide, 1st edition (`docs/reference/`): chapter 11
  "C64U Networking and Wi-Fi" (pp. 145–153), chapter 12
  "C64U Modem Emulation" (pp. 155–160). Page numbers are the printed
  page numbers.
- `roadmap.md` — milestones and open questions.

# C64U Communication Layer (Milestone 1)

This document describes the **internal** C64 Ultimate communication
layer of GameNet (architecture layer 3, see
[`architecture.md`](architecture.md)) and the C64U configuration it
requires.

It is written for GameNet developers. Games never use anything in
this document directly: `$DE00`, ACIA registers, AT commands, IP
addresses and ports are implementation details hidden behind the
(future) GameNet API.

Every hardware-specific statement is tagged with its source. Anything
that no source establishes is listed under [Open Questions](#open-questions)
and must not be relied on until verified.

---

## Sources

| Tag      | Source | Status |
|----------|--------|--------|
| **[UG]** | *Commodore 64 Ultimate User Guide*, 1st edition — `docs/reference/c64u-user-guide-1st-edition.pdf`. Page numbers are the **printed** page numbers (PDF page = printed page + 29). Chapter 12 "C64U Modem Emulation", pp. 155–160. | Project reference, **authoritative** for C64U behaviour. |
| **[6502]** | *6502 Assembly Language Programming for Apple, Commodore and Atari Computers* — `docs/reference/6502-assembly-language-programming-for-apple-commodore-and-atari-computers.pdf`. Printed page numbers. | Project reference for CPU / KERNAL usage. |
| **[U2]** | Ultimate firmware documentation, "Modem support", G. Zweijtzer, <https://1541u-documentation.readthedocs.io/en/latest/howto/modem.html> (retrieved 2026-10-08). | **External**, not in `docs/reference/`. Describes the Ultimate-II+/Ultimate 64 firmware modem layer. Its text is nearly identical to [UG] ch. 12 but it is **not** a C64U document; facts taken only from [U2] are marked as needing C64U verification. |
| **[WDC]** | Western Design Center, *W65C51N Asynchronous Communications Interface Adapter* datasheet, 18 March 2024, pp. 11–15 (register tables), <https://www.westerndesigncenter.com/wdc/documentation/w65c51n.pdf>. | **External**. Consulted through text excerpts only: the full PDF could not be downloaded in this session (connection failure). The W65C51N is a later CMOS part with known differences from the MOS 6551 (see Open Questions). Must be re-checked against a full MOS/Rockwell 6551 datasheet. |
| **[CMP]** | "Experimenting with the 6551 ACIA", *COMPUTE!* issue 10, Listing 1, <https://www.atarimagazines.com/compute/issue10/075_1_EXPERIMENTING_WITH_THE_6551_ACIA.php>. | **External**, secondary. Used only to corroborate register offsets and the TDRE/RDRF bit positions. |

A further web page (MJK's "ACIA 6551", ist.uwaterloo.ca) was consulted
and **rejected**: it marks itself "NOT VERIFIED" and its status-bit
numbering contradicts both [WDC] and [CMP].

---

## What the C64U provides

- The C64U has built-in modem emulation that connects over the
  Internet via Telnet, over Ethernet or Wi-Fi. **[UG] p. 157**
- The C64U emulates the **MOS 6551 ACIA**, as found in the SwiftLink
  cartridge and other RS-232 cartridges. **[UG] p. 157**
- Network setup (Ethernet/Wi-Fi, DHCP/static IP) is in chapter 11.
  **[UG] pp. 145–153**

GameNet uses this emulated 6551 purely as a byte pipe. The C64U does
all networking.

---

## C64U configuration

### Modem emulation / ACIA mapping / SwiftLink mode

Modem emulation is **disabled by default**. To enable it **[UG] p. 157**:

1. Open the C64U Menu, select **"Modems"**.
2. Select **"ACIA (6551) Mapping"** and set it to **`DE00/NMI`**.
3. Ensure **"Hardware Mode"** is **`SwiftLink`**.
4. Exit the menu and save the settings to flash when prompted.

`DE00` is the memory address at which the ACIA appears. Other C64U
features (extra SID chips, utility cartridges such as Retro Replay)
can be configured to conflict with it. **[UG] p. 158**. [U2] adds that
the Ultimate does **not** enforce I/O-range conflicts and that wrong
characters in a terminal program usually indicate such a conflict.

GameNet Milestone 1 uses **only** `DE00/NMI` + `SwiftLink`, exactly as
documented in [UG]. Other mappings (an external source, C64 OS,
mentions `DF00` and `DF80` options) are not used and not documented
by [UG].

### `DE00/NMI` — what "NMI" means

[UG] p. 157 says the mapping connects the ACIA "to a memory address
and interrupt interface"; the setting name says the interrupt line is
the NMI. [U2] notes that CCGMS uses the NMI line. **Nothing in the
references describes when the emulated ACIA asserts NMI or how it is
acknowledged.** Milestone 1 therefore programs the ACIA with its
receiver interrupt **disabled** (see [Register mapping](#register-mapping-used))
and uses polling only. See Open Questions.

### Listening port (answering side)

The modem emulation listens for incoming connections on a numbered
TCP port "such as 3000", set in the modem configuration.
**[UG] p. 159**. [U2] shows port 3000 as the configured example; the
exact name of the menu item is not given in [UG] (see Open
Questions).

### Incoming-call behaviour and messages

When another node connects to the listening port, the C64U behaves
according to its modem state **[UG] p. 160**:

| State   | Condition | What the **calling** party receives |
|---------|-----------|-------------------------------------|
| Offline | `DTR=0`: the ACIA is not configured/enabled, i.e. modem software not running | Contents of the configured file (default `/Usb0/offline.txt`), else the default text "Modem Software is currently not running…" |
| Busy    | The modem already has an active connection | Configured file (default `/Usb0/busy.txt`), else "The modem you are connecting to is currently busy." |
| Ready   | The modem is configured and software is ready | Configured file (default `/Usb0/connect.txt`), else "Welcome to the Modem Emulation Layer of the Commodore 64 Ultimate!" — **then the RING sequence begins** (if enabled) |

In the Ready state with the RING sequence enabled, the program on the
**answering** C64 receives `RING` messages and must answer with `ATA`.
**[UG] p. 160**. If `ATA` is not given in time, the incoming call
times out after a number of rings. **[UG] p. 159 (ATA)**

[U2] (not [UG]) adds:

- Setting a message filename to an empty string suppresses that
  message entirely.
- The handshake-line states the terminal program "sees" are
  configurable; they are set when a connection is established or
  terminated. **By default CTS is always active, and DCD and DSR are
  only active during an active connection.**

### Router / firewall

Connections between two C64Us on the same local network use the
answering C64U's local IP address, shown in the network setup screen
(Disk File Browser / network menu). **[UG] pp. 147, 151, 159**.
Connections from outside the local network need router configuration
that is outside the guide's scope **[UG] p. 159** and outside
GameNet's scope.

---

## Modem commands

The modem accepts a subset of the Hayes AT command set; commands are
typed and terminated with RETURN. **[UG] p. 158**

| Command | Meaning **[UG] pp. 158–159** | Used by GameNet M1 |
|---------|------------------------------|--------------------|
| `ATI`   | Print modem identification text | no |
| `ATZ`   | Reset modem; drops any existing connection | no |
| `ATH`   | Hang up current connection | **yes** |
| `ATD`   | Dial. `D` is followed by a character (usually `T`/`P`) that the C64U ignores, then the domain name, optional `:port` (default port **80**). Example `ATDTAFTERLIFE.DYNU.COM:6400` | **yes** (`ATDT<host>:<port>`) |
| `ATA`   | Answer an incoming call; **required** when "Do RING sequence" is Enabled | **yes** |
| `ATO`   | Return online after `+++` | no |
| `ATV`   | Recognised but ignored | no |
| `ATS`   | Read/set S-registers: `S0` auto answer, `S1` ring counter, `S2` escape character, `S12` escape time | no |
| `+++`   | Escape: when three escape characters (`S2`, default `+`) are sent and at least `S12` jiffies (default 50 = one second) expire, the modem switches to command mode; the connection stays active and e.g. `ATH` can be given | **yes** (hang-up) |

GameNet sends AT commands as upper-case ASCII bytes terminated by
`$0D` (carriage return), matching the upper-case example in [UG]
p. 158.

---

## Connection procedure used by Milestone 1

```text
C64U B (answerer)                         C64U A (caller)
-----------------                         ---------------
init ACIA (DTR=1)  -> modem state Ready   init ACIA (DTR=1)
                                          ATDT <B-ip>:<B-port><CR>
           <---------- TCP connection -----------
                                          receives connect message
                                          ("Welcome to the Modem
                                          Emulation Layer ...")   [UG p.160]
receives "RING" (repeated)   [UG p.160]
ATA<CR>                      [UG p.159]
           ===== link carries program data =====
test protocol (see docs/milestone1-hardware-test.md)
+++ (guard time) ATH<CR>     [UG p.158-159]   +++ (guard time) ATH<CR>
ACIA disabled (DTR=0) -> Offline              ACIA disabled (DTR=0)
```

Because the references do **not** document the modem's command
responses (`OK`, `CONNECT`, `NO CARRIER`, echo, …), the layer does
**not** parse them. Instead the test program skips everything until it
sees an application-defined sync marker sent by the other C64 (see
`docs/milestone1-hardware-test.md`). This also discards the connect
message/banner that the caller receives. Alternatively the banner can
be suppressed by an empty `connect` message filename [U2] — not
required.

---

## Register mapping used

The 6551 occupies four consecutive addresses from its base address
(register-select offsets 0–3) **[CMP] Listing 1, [WDC]**. With the
`DE00/NMI` mapping the base is `$DE00` **[UG] p. 157**. Defined in
`src/include/c64u.inc`.

| Address | Read | Write | Constant |
|---------|------|-------|----------|
| `$DE00` | Receiver data | Transmitter data | `ACIA_DATA` |
| `$DE01` | Status | Programmed (software) reset | `ACIA_STATUS` |
| `$DE02` | Command | Command | `ACIA_COMMAND` |
| `$DE03` | Control | Control | `ACIA_CONTROL` |

### Status register **[WDC] p. 11; TDRE/RDRF corroborated by [CMP]**

| Bit | Mask | Meaning | Constant |
|-----|------|---------|----------|
| 7 | `$80` | Interrupt has occurred (cleared by reading status) | `ACIA_ST_IRQ` |
| 6 | `$40` | DSR: **0 = ready**, 1 = not ready | `ACIA_ST_DSR` |
| 5 | `$20` | DCD: **0 = carrier detected**, 1 = not detected | `ACIA_ST_DCD` |
| 4 | `$10` | Transmitter data register empty | `ACIA_ST_TDRE` |
| 3 | `$08` | Receiver data register full (cleared by reading data) | `ACIA_ST_RDRF` |
| 2 | `$04` | Overrun | `ACIA_ST_OVRN` |
| 1 | `$02` | Framing error | `ACIA_ST_FE` |
| 0 | `$01` | Parity error | `ACIA_ST_PE` |

### Command register **[WDC] pp. 14–15**

| Bits | Meaning | Constant |
|------|---------|----------|
| 0 | DTR: 1 = data terminal ready (enables receiver/interrupts) | `ACIA_CMD_DTR` |
| 1 | 1 = receiver interrupt (IRQ line) disabled | `ACIA_CMD_RX_IRQ_OFF` |
| 3–2 | `10` = RTS low, transmit interrupt disabled | `ACIA_CMD_RTS_ON` |
| 4 | 1 = receiver echo mode | (not used, 0) |
| 7–5 | parity mode; `xx0` = parity disabled | (not used, 0) |

### Control register **[WDC] pp. 11–12**

| Bits | Meaning | Constant |
|------|---------|----------|
| 3–0 | Baud rate; `1111` = 19,200 | `ACIA_CTL_BAUD_19200` |
| 4 | 1 = receiver clock from baud-rate generator | `ACIA_CTL_RX_BAUDGEN` |
| 6–5 | word length; `00` = 8 bits | `ACIA_CTL_8BITS` |
| 7 | stop bits; 0 = 1 stop bit | (0) |

### Values programmed by `c64u_init`

| Register | Value | Meaning |
|----------|-------|---------|
| Status (write) | any | programmed reset |
| Control | `$1F` | 8 data bits, 1 stop bit, internal receiver clock, rate code 19,200 |
| Command | `$0B` | DTR active, receiver IRQ **disabled**, RTS low / transmit IRQ disabled, no echo, no parity |

Rationale:

- **8 data bits, no parity** — needed to carry arbitrary byte values.
- **19,200** — the only rate shown in [UG] (p. 158, CCGMS example).
  Whether the emulation honours or ignores the rate is unknown.
- **DTR active** — [UG] p. 160 ties the "Offline" state to `DTR=0`;
  setting DTR is what moves the answering modem to "Ready".
- **Interrupts disabled** — keeps Milestone 1 polled and avoids
  undocumented NMI behaviour. Background reception is Milestone 3.

`c64u_shutdown` writes command `$02` (DTR inactive, receiver IRQ
disabled), returning the modem to the documented Offline state.

---

## Communication-layer API (internal)

Source: `src/c64u/acia.s` (hardware access) and `src/c64u/modem.s`
(minimal modem commands). These symbols are **internal** and will be
wrapped by the GameNet implementation; they are not a public API and
are not final.

### `src/c64u/acia.s`

| Routine | In | Out | Modifies | Notes |
|---------|----|-----|----------|-------|
| `c64u_init` | – | – | A, flags | Programmed reset, control `$1F`, command `$0B`, discards a stale received byte and clears the IRQ flag. |
| `c64u_status` | – | A = raw status register; N/Z set from it | A, flags | Reading status clears status bit 7 (IRQ). |
| `c64u_send` | A = byte | – | flags (A, X, Y preserved) | **Blocking** poll until TDRE=1, then writes the byte. Never times out. |
| `c64u_receive` | – | C=1: A = received byte; C=0: no byte (A=0) | A, flags (X, Y preserved) | Non-blocking. Also stores the status value read into `c64u_rx_status`, so callers can check `ACIA_ST_ERRORS`. |
| `c64u_shutdown` | – | – | A, flags | Command `$02` (DTR inactive). |
| `c64u_rx_status` | (variable, 1 byte) | status register as read by the last `c64u_receive` | – | |

### `src/c64u/modem.s`

| Routine | In | Out | Modifies | Notes |
|---------|----|-----|----------|-------|
| `c64u_delay` | A = units of ≈10 ms (0 = 256) | – | A, X, Y, flags | Software delay loop. |
| `c64u_send_string` | A/Y = low/high address of a zero-terminated string (≤ 255 bytes) | – | A, Y, flags | Uses `c64u_send` (blocking). |
| `c64u_modem_dial` | A/Y = address of zero-terminated `host:port` | – | A, Y, flags | Sends `ATDT`, the string, `$0D`. |
| `c64u_modem_answer` | – | – | A, Y, flags | Sends `ATA` `$0D`. |
| `c64u_modem_hangup` | – | – | A, X, Y, flags | ≈1.5 s silence, `+++`, ≈1.5 s silence, `ATH` `$0D`. |

### Resource usage

| Resource | Usage |
|----------|-------|
| Zero page | **none** |
| RAM (BSS) | `acia.s`: 1 byte (`c64u_rx_status`); `modem.s`: 1 byte (delay counter) |
| Code / constant data | `acia.s`: 63 bytes `CODE`; `modem.s`: 96 bytes `CODE` + 15 bytes `RODATA` (from `build/commtest.map`). Total 174 bytes. |
| I/O | `$DE00–$DE03` only |
| Interrupts | none used; the layer does not change the I flag or any vector. ACIA interrupts are disabled. |
| Stack | at most 3 bytes (JSR + one PHA) |
| Self-modifying code | `c64u_send_string` patches the operand of its own load instruction, so the module must run from RAM (true for a loaded `.prg`). Not re-entrant (not callable from an interrupt handler while in use). |

### Cycle-sensitive behaviour

- `c64u_send` busy-waits on TDRE. Its time therefore depends on how
  fast the emulated ACIA accepts bytes, which is **not documented**.
  The poll loop is 9 cycles per iteration (`LDA abs` 4, `AND #` 2,
  `BEQ` taken 3).
- `c64u_receive` takes about 21 cycles when no byte is waiting
  (excluding JSR/RTS). The 6551 has a single receive data register
  [WDC]; if a new byte arrives before the previous one is read, an
  overrun results. Whether the C64U emulation buffers incoming data
  is **not documented**. Callers must therefore poll often enough and
  avoid slow work (e.g. KERNAL screen output) while data is
  streaming.
- `c64u_delay` is a pure CPU loop of ≈10,250 cycles per unit
  (≈10 ms at a ≈1 MHz CPU clock; the C64 clock frequency is not given
  by the project references). Interrupts (the KERNAL IRQ stays
  enabled) can only lengthen it. All uses (`+++` guard time) need a
  *minimum* time, so lengthening is harmless.
- `+++` handling: [UG] p. 159 requires at least `S12` jiffies (default
  1 s) after the three escape characters. `c64u_modem_hangup` waits
  ≈1.5 s before and after, which also satisfies the conventional Hayes
  guard time before `+++` (not stated in [UG]).

---

## Binary data and modem escape

- Game data is arbitrary bytes. Per [UG] p. 159 the escape sequence is
  three consecutive escape characters (`+` by default) **followed by**
  at least `S12` jiffies with (presumably) no further data. The test
  patterns never contain two consecutive `+` (`$2B`) bytes.
- [UG] does **not** say whether the escape detector requires a guard
  time *before* the `+++`, whether the characters must be consecutive,
  or how the escape can be disabled. A future GameNet layer will need
  a rule (e.g. never let `+++` be followed by silence, or set `S2` to
  a value that cannot occur) — **to be decided after hardware
  verification** (Open Questions).
- [UG] p. 157 describes the link as Telnet. Telnet normally treats
  byte `$FF` specially; whether the C64U escapes, strips or passes
  `$FF` (and `$0D`, `$00`) is **not documented**. The Milestone 1 test
  sends all 256 byte values in both directions specifically to answer
  this.

---

## Emulator (VICE) limitations

VICE is **not installed** on the development machine, so nothing was
run in VICE. VICE can emulate a SwiftLink/ACIA connected to a host
TCP socket (general VICE knowledge, not a project reference), but it
does **not** emulate the C64U's modem layer (AT command interpreter,
`RING`/`ATA` answer sequence, connect/busy/offline messages, `+++`
handling, the C64U's DCD/DSR behaviour). A VICE run therefore could
not verify Milestone 1 even if performed, and none is claimed.

What was verified off-hardware:

- the code assembles and links (`.\build.ps1 verify`), and the GNU
  Make build produces byte-identical `.prg` files;
- `.prg` structure (load address, BASIC `SYS` line);
- symbol placement and sizes (map/label files);
- **program logic** with `tools/sim/commtest_sim.py`: the real
  `build/commtest.prg` runs on two simulated 6502 CPUs (py65) linked
  by a *model* of the ACIA and modem built from [UG] ch. 12 plus
  pessimistic assumptions (single receive register with overrun,
  optional echo/result strings, missing banner, corrupted links). All
  six scenarios behave as expected: four pass, and the two corrupted
  links (`$FF` dropped, bit 7 stripped) are reported as FAIL on both
  machines. This verifies the test program's logic only — **not** the
  C64U.

Everything about real C64U behaviour requires two physical C64
Ultimate systems — see
[`milestone1-hardware-test.md`](milestone1-hardware-test.md).

---

## Open Questions

Not established by the references. Each item says how it will be
answered.

1. **6551 register layout and bit meanings as emulated by the C64U.**
   [UG] only names the chip (p. 157). The layout used comes from the
   external [WDC]/[CMP] sources. *Verify:* on hardware the test prints
   the raw status register at each stage; it must show TDRE=1 when
   idle and the program must be able to send/receive at all.
2. **Exact MOS 6551 vs W65C51N differences.** [WDC] documents the
   CMOS W65C51N, whose TDRE bit is "always 1" (a known difference from
   the original 6551). The C64U claims to emulate the MOS 6551. *Verify:*
   obtain a full MOS/Rockwell 6551 datasheet for `docs/reference/`
   (the Rockwell PDF found online is a scan without text).
3. **Baud-rate behaviour.** [UG] only shows "19200" as a CCGMS example
   (p. 158). Whether the emulation honours the control-register rate,
   ignores it, or (as on a real SwiftLink, per common knowledge, not a
   reference) doubles it, is unknown. *Verify:* time a 256-byte
   transfer on hardware with different rate codes.
4. **Binary transparency.** Whether all 256 byte values pass
   unchanged (Telnet `$FF`/IAC, `$0D`/`$00` handling, high bit) is not
   documented. *Verify:* the two-machine test (all 256 values each
   way).
5. **Connection state detection.** [UG] documents only the Offline
   condition (DTR=0, p. 160). [U2] says DCD and DSR are active only
   during a connection by default; the status-bit polarity (0 = active
   per [WDC]) as emulated is unverified. Modem result strings
   (`CONNECT`, `NO CARRIER`, …) are not documented in [UG]. *Verify:*
   the test displays the status register before connection, while
   connected and after hang-up.
6. **NMI behaviour.** Only the `DE00/NMI` mapping name is documented.
   When NMI is asserted, whether it is level/edge, and how it is
   acknowledged are unknown. M1 disables ACIA interrupts. *Verify* in
   Milestone 3.
7. **Interaction between modem commands and raw data.** Whether the
   modem echoes characters in command mode, what it replies to `ATDT`,
   `ATA` and `ATH`, and how long after `ATA` the link carries data are
   not documented. The test tolerates any of this by waiting for
   sync markers. *Verify:* observe the caller's screen (it displays
   all received text before sync).
8. **Accidental escape by game data.** [UG] p. 159 documents `+++`
   plus `S12` jiffies but not guard time before, whether non-adjacent
   `+` characters count, or how to disable escape (e.g. `S2` > 127, a
   Hayes convention not stated in [UG]). *Verify* on hardware before
   Milestone 2 defines framing.
9. **Receive buffering / flow control.** Whether the emulated ACIA
   buffers more than one received byte, and whether CTS/RTS
   flow-control is honoured ([U2]: "CTS is always active" by default),
   is not documented. *Verify:* check the overrun bit reported by the
   test.
10. **Menu item names** for the listening port, "Do RING sequence" and
    message files. [UG] refers to "the modem configuration" and the
    option "Do RING sequence" (p. 159) but does not show the menu
    screen. *Verify:* record the actual menu labels during the
    hardware test.
11. **RING timing / number of rings before timeout** ([UG] p. 159:
    "after a number of rings") — `S1`/`S0` semantics are only referred
    to the Hayes specification. Not needed for M1 beyond "answer
    promptly".
12. **Banner text.** The default text differs between [UG] ("…of the
    Commodore 64 Ultimate!") and [U2] ("…of the Ultimate!"); the
    actual firmware text should be recorded. The test does not depend
    on it.

# Milestone 1 — Two-Machine C64 Ultimate Test Procedure

This is the procedure for verifying the C64U communication layer on
**two physical C64 Ultimate systems** with `build/commtest.prg`.

> **Status: NOT YET PERFORMED.** No physical hardware test has been
> carried out. The results section below is empty. Milestone 1 stays
> incomplete until it has been filled in from a real run.

Background, sources and open questions:
[`c64u-communication.md`](c64u-communication.md). Page numbers refer
to the C64U User Guide, 1st edition (printed pages) — "[UG]".

---

## 1. What is needed

- Two C64 Ultimate systems, called **A (caller)** and **B (answerer)**.
- Both on the **same local network** (Ethernet or Wi-Fi, [UG] ch. 11).
  Connections from outside the local network need router setup that
  is out of scope ([UG] p. 159).
- `build/commtest.prg` (build with `.\build.ps1 verify`) on USB
  storage/SD card of each C64U, or uploaded via the C64U FTP file
  service ([UG] p. 151).
- No cartridge or C64U feature that uses `$DE00` (e.g. extra SID at
  `DE00`, Retro Replay) may be active ([UG] p. 158).

## 2. C64U configuration (both machines)

1. **Network** — connect Ethernet or Wi-Fi. In "Wired Network Setup"
   or "Wi-Fi Network Setup", confirm the "Active IP address" is not
   `0.0.0.0` ([UG] p. 147). **Write down B's IP address.**
2. **Modem** — C64U Menu → "Modems" ([UG] p. 157):
   - "ACIA (6551) Mapping" = **`DE00/NMI`**
   - "Hardware Mode" = **`SwiftLink`**
3. **B only (answerer)** — in the modem configuration:
   - Listening port: e.g. **`3000`** ([UG] p. 159). **Write it down.**
   - "Do RING sequence" = **Enabled** (the test waits for `RING` and
     answers with `ATA`, [UG] pp. 159–160).
   - Leave the connect/busy/offline message files at their defaults
     (the test skips whatever banner arrives).
4. Exit the menu and **save settings to flash** when prompted
   ([UG] p. 157).

Record the exact menu labels you see (Open Question 10).

## 3. Running the test

Order matters: **B must be waiting before A dials**, otherwise A gets
the "Offline" message ([UG] p. 160).

1. **B:** run `COMMTEST` from the Disk File Browser ([UG] p. 27), or
   `LOAD"COMMTEST",8` and `RUN` from a disk image. Press **`A`**.
   Expected:

   ```text
   ROLE: ANSWERER (B)
   INIT ACIA $DE00... OK
    STATUS $xx DCD=x DSR=x
   WAITING FOR CALL (KEY ABORTS)
   MODEM TEXT:
   ```

2. **A:** run `COMMTEST`, press **`C`**. At the prompt type B's address
   and port, e.g. `192.168.0.64:3000`, and press RETURN (DEL corrects).
   A sends `ATDT192.168.0.64:3000` ([UG] p. 158) and shows all text
   it receives, e.g. the connect banner ([UG] p. 160).
3. **B** should show `RING`, then `RING SEEN - SENDING ATA`,
   `SENDING SYNC, WAITING FOR CALLER`.
4. **A** should show `#GNA` and `CONNECTED: ANSWERER SYNC RECEIVED`;
   **B** shows `CONNECTED: CALLER SYNC RECEIVED`.
5. **A → B:** A prints `SENDING A->B $00..$FF ........ 256 SENT`.
   B prints the count, mismatches, ACIA error bits, three rows of
   received values and `DIRECTION RESULT: PASS/FAIL`. Expected rows:

   ```text
   00: 00 01 02 03 04 05 06 07
   7C: 7C 7D 7E 7F 80 81 82 83
   F8: F8 F9 FA FB FC FD FE FF
   ```

6. **B → A:** B sends `$FF..$00`. A shows the same information, with
   expected rows:

   ```text
   00: FF FE FD FC FB FA F9 F8
   7C: 83 82 81 80 7F 7E 7D 7C
   F8: 07 06 05 04 03 02 01 00
   ```

7. Both screens show `A->B:`, `B->A:` and `OVERALL: PASS` or `FAIL`,
   then `HANGING UP (+++ ATH)` (takes about 3 s, [UG] pp. 158–159),
   a final status line and `DONE`, and return to BASIC.

**Take a photo of both screens** at the end (and of A's screen after
the banner, step 4).

Timeouts are approximate: B waits up to ~14 min for a call; A waits
~2 min for the answer; any key aborts these waits. All other waits
time out on their own and report `TIMEOUT` / `NOT REPORTED`.

## 4. Interpreting results

| Observation | Meaning |
|---|---|
| `OVERALL: PASS` on both | All 256 byte values passed unchanged in both directions (answers Open Question 4 for this setup). |
| A shows "Modem Software is currently not running" | B's ACIA not initialised / B not waiting (Offline state, [UG] p. 160). |
| A shows "...currently busy." | B already has a connection (Busy, [UG] p. 160). |
| No `RING` on B | Wrong IP/port, "Do RING sequence" disabled, network/firewall issue. |
| Wrong characters / nothing at all | Possible `$DE00` conflict ([UG] p. 158, [U2]). |
| `TIMEOUT: RECEIVED ONLY $nn BYTES` | Bytes lost or swallowed (e.g. `$FF` handled as Telnet IAC — Open Question 4). |
| Mismatches with `GOT` = `EXP` & `$7F` | High bit stripped (not 8-bit clean). |
| ACIA PE/FE/OVRN bits ≠ `$00` | Overrun or line errors (Open Question 9). |
| Status `DCD=`/`DSR=` values | Record them before connection, while connected and after hang-up (Open Question 5). Per [WDC] 0 = active. |

## 5. Optional follow-up measurements

Only if the basic test passes, and recorded separately:

- Time the 256-byte transfers with a stopwatch (Open Question 3).
- Repeat with the connect message suppressed (empty filename, [U2]).
- Repeat with machines swapped (B calls A).

---

## 6. Results record

Fill in after a real run. **Do not** fill in from simulation.

| Item | Value |
|---|---|
| Date / tester | |
| C64U firmware version (A / B) | |
| Network (Ethernet / Wi-Fi, same LAN?) | |
| A IP / B IP / B listening port | |
| Menu labels seen (modem settings) | |
| A config (mapping / hardware mode) | |
| B config (mapping / mode / port / RING) | |
| Text shown on A before sync (banner, results, echo) | |
| Text shown on B before RING / after ATA | |
| Status before / connected / after (A) | |
| Status before / connected / after (B) | |
| A → B: received count / mismatches / ACIA bits | |
| B → A: received count / mismatches / ACIA bits | |
| OVERALL on A / on B | |
| Hang-up behaviour (did B notice? text shown?) | |
| Failures / unexpected behaviour | |
| Photos (file names) | |

### Physical test log

_No physical test has been performed yet._

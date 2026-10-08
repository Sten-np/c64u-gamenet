#!/usr/bin/env python3
"""
commtest_sim.py - LOGIC simulation of the Milestone 1 two-machine test.

THIS IS NOT HARDWARE OR EMULATOR VERIFICATION.

It runs the real build/commtest.prg on two simulated 6502 CPUs (py65)
connected through a *model* of the C64U ACIA + modem emulation. The
model implements only behaviour documented in the C64U User Guide
(ch. 12: ATDT/ATA/ATH, banner to the caller, RING to the answerer,
"+++" followed by S12 jiffies of silence, DTR=0 = offline) plus
deliberately pessimistic assumptions for the undocumented parts
(single-byte receive register with overrun, optional command echo,
optional result strings, optional byte corruption). It checks the
test program's own logic: sync, banner skipping, pattern transfer,
verification, verdict exchange, hang-up. It says nothing about real
C64U behaviour - see docs/c64u-communication.md, Open Questions.

The KERNAL is not emulated: CHROUT ($FFD2) and GETIN ($FFE4) are
trapped; X and Y are randomised on return because the project
references do not document their preservation. No IRQs are run.

Requires: Python 3.8+, py65 (pip install py65).

Usage:
    python tools/sim/commtest_sim.py [--scenario NAME|all] [--verbose]
"""

import argparse
import collections
import os
import random
import sys

try:
    from py65.devices.mpu6502 import MPU
    from py65.memory import ObservableMemory
except ImportError:  # pragma: no cover
    sys.exit("py65 is required: pip install py65")

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PRG = os.path.join(ROOT, "build", "commtest.prg")

# Addresses (same as src/include/c64.inc / c64u.inc)
CHROUT, GETIN = 0xFFD2, 0xFFE4
ACIA_DATA, ACIA_STATUS, ACIA_COMMAND, ACIA_CONTROL = 0xDE00, 0xDE01, 0xDE02, 0xDE03
ST_OVRN, ST_RDRF, ST_TDRE, ST_DCD, ST_DSR = 0x04, 0x08, 0x10, 0x20, 0x40
RETURN_SENTINEL = 0xC000            # "back to BASIC" when PC reaches this

# Model timing, in CPU cycles (~1 MHz)
CPS = 1_000_000
BYTE_CYCLES = 520                   # ~19200 baud byte time
LINK_LATENCY = 5_000                # 5 ms network latency
RING_INTERVAL = CPS                 # 1 s between RINGs
MAX_RINGS = 10
ESCAPE_GUARD = CPS                  # S12 = 50 jiffies = 1 s  [UG p.159]
BANNER = "Welcome to the Modem Emulation Layer of the Commodore 64 Ultimate!\r\n"  # [UG p.160]


class Scenario:
    def __init__(self, name, fifo=False, echo=False, results=False,
                 corrupt=None, answerer_dtr=True, banner=True):
        self.name = name
        self.fifo = fifo            # True: unlimited receive buffering
        self.echo = echo            # echo characters in command mode
        self.results = results      # send OK/CONNECT/NO CARRIER strings
        self.corrupt = corrupt      # function(byte) -> list of bytes
        self.answerer_dtr = answerer_dtr
        self.banner = banner
        self.expect_pass = corrupt is None and answerer_dtr


SCENARIOS = {
    "strict": Scenario("strict"),
    "fifo": Scenario("fifo", fifo=True),
    "chatty": Scenario("chatty", echo=True, results=True),
    "nobanner": Scenario("nobanner", banner=False, echo=True, results=True),
    "drop_ff": Scenario("drop_ff", corrupt=lambda b: [] if b == 0xFF else [b]),
    "strip_bit7": Scenario("strip_bit7", corrupt=lambda b: [b & 0x7F]),
}


class Modem:
    """Model of one C64U modem emulation (documented behaviour only)."""

    def __init__(self, machine, scenario):
        self.m = machine
        self.sc = scenario
        self.peer = None
        self.dtr = False
        self.online = False         # data mode
        self.connected = False      # TCP connection exists
        self.incoming = False       # ringing
        self.next_ring = 0
        self.rings = 0
        self.cmd = bytearray()
        self.plus = 0
        self.last_tx = 0
        self.log = []

    def to_c64(self, text, now):
        data = text.encode("ascii") if isinstance(text, str) else bytes(text)
        for b in data:
            self.m.rx_queue.append((now, b))

    def result(self, text, now):
        if self.sc.results:
            self.to_c64("\r\n" + text + "\r\n", now)

    def from_c64(self, b, now):
        if self.online:
            self.plus = self.plus + 1 if b == ord("+") else 0
            self.last_tx = now
            if self.peer.online:
                out = self.sc.corrupt(b) if self.sc.corrupt else [b]
                for o in out:
                    self.peer.m.rx_queue.append((now + LINK_LATENCY, o))
            return
        if self.sc.echo:
            self.to_c64(bytes([b]), now)
        if b == 0x0D:
            line = self.cmd.decode("ascii", "replace").strip().upper()
            self.cmd = bytearray()
            if line:
                self.command(line, now)
        else:
            self.cmd.append(b)

    def command(self, line, now):
        self.log.append((now, line))
        if line.startswith("ATD"):
            p = self.peer
            if not p.dtr:
                self.to_c64("Modem Software is currently not running...\r\n", now + LINK_LATENCY)
                return
            if p.connected:
                self.to_c64("The modem you are connecting to is currently busy.\r\n", now + LINK_LATENCY)
                return
            self.connected = p.connected = True
            self.online = True
            self.result("CONNECT", now + LINK_LATENCY)
            if self.sc.banner:
                self.to_c64(BANNER, now + LINK_LATENCY)
            p.incoming = True
            p.rings = 0
            p.next_ring = now + RING_INTERVAL
        elif line == "ATA":
            if self.incoming:
                self.incoming = False
                self.online = True
                self.result("CONNECT", now)
            else:
                self.result("ERROR", now)
        elif line == "ATH":
            self.hangup(now)
            self.result("OK", now)
        else:
            self.result("OK", now)

    def hangup(self, now):
        if self.connected:
            p = self.peer
            self.connected = self.online = self.incoming = False
            if p.connected:
                p.connected = p.online = p.incoming = False
                p.result("NO CARRIER", now + LINK_LATENCY)

    def tick(self, now):
        if self.incoming and now >= self.next_ring:
            self.to_c64("\r\nRING\r\n", now)
            self.rings += 1
            self.next_ring = now + RING_INTERVAL
            if self.rings > MAX_RINGS:
                self.incoming = False
                self.peer.hangup(now)
        if self.online and self.plus >= 3 and now - self.last_tx >= ESCAPE_GUARD:
            self.online = False
            self.plus = 0
            self.result("OK", now)


class Machine:
    def __init__(self, name, prg, keys, scenario, rng):
        self.name = name
        self.sc = scenario
        self.rng = rng
        self.mem = ObservableMemory()
        load = prg[0] | (prg[1] << 8)
        for i, b in enumerate(prg[2:]):
            self.mem[load + i] = b
        self.mem[CHROUT] = 0x60          # RTS (trapped before execution)
        self.mem[GETIN] = 0x60
        self.mem.subscribe_to_read(range(ACIA_DATA, ACIA_CONTROL + 1), self.acia_read)
        self.mem.subscribe_to_write(range(ACIA_DATA, ACIA_CONTROL + 1), self.acia_write)
        sys_addr = int(bytes(prg[7:11]).decode())
        self.mpu = MPU(memory=self.mem, pc=sys_addr)
        ret = RETURN_SENTINEL - 1
        self.mem[0x1FF] = ret >> 8
        self.mem[0x1FE] = ret & 0xFF
        self.mpu.sp = 0xFD
        self.keys = collections.deque(keys)   # (available_at_cycle, code)
        self.screen = []
        self.rx_queue = collections.deque()   # (arrival_cycle, byte)
        self.rdr = 0
        self.rdrf = False
        self.ovrn = False
        self.next_rx = 0
        self.cmd = 0
        self.ctl = 0
        self.modem = Modem(self, scenario)
        self.done = False
        self.overruns = 0

    # --- ACIA model --------------------------------------------------
    def now(self):
        return self.mpu.processorCycles

    def status(self):
        st = ST_TDRE
        if self.rdrf:
            st |= ST_RDRF
        if self.ovrn:
            st |= ST_OVRN
        if not self.modem.connected:
            st |= ST_DCD | ST_DSR        # inactive (1) when no connection [U2]
        return st

    def acia_read(self, addr):
        if addr == ACIA_DATA:
            v = self.rdr
            self.rdrf = False
            self.ovrn = False
            return v
        if addr == ACIA_STATUS:
            return self.status()
        if addr == ACIA_COMMAND:
            return self.cmd
        return self.ctl

    def acia_write(self, addr, value):
        if addr == ACIA_DATA:
            self.modem.from_c64(value, self.now())
        elif addr == ACIA_STATUS:          # programmed reset
            self.ovrn = False
            self.cmd &= 0xE0
            self.modem.dtr = False
        elif addr == ACIA_COMMAND:
            self.cmd = value
            dtr = bool(value & 1)
            if self.name == "B" and not self.sc.answerer_dtr:
                dtr = False
            self.modem.dtr = dtr
        else:
            self.ctl = value

    def deliver(self):
        now = self.now()
        while self.rx_queue and self.rx_queue[0][0] <= now and now >= self.next_rx:
            if self.rdrf and self.sc.fifo:
                return
            _, b = self.rx_queue.popleft()
            if self.rdrf:
                self.ovrn = True            # previous byte lost
                self.overruns += 1
            self.rdr = b
            self.rdrf = True
            self.next_rx = now + BYTE_CYCLES

    # --- KERNAL traps ------------------------------------------------
    def trap(self):
        pc = self.mpu.pc
        if pc == CHROUT:
            self.screen.append(self.mpu.a)
        elif pc == GETIN:
            if self.keys and self.keys[0][0] <= self.now():
                self.mpu.a = self.keys.popleft()[1]
            else:
                self.mpu.a = 0
        else:
            return
        self.mpu.x = self.rng.randrange(256)
        self.mpu.y = self.rng.randrange(256)

    def run(self, instructions):
        for _ in range(instructions):
            if self.mpu.pc == RETURN_SENTINEL:
                self.done = True
                return
            self.trap()
            self.mpu.step()
            self.deliver()
        self.modem.tick(self.now())

    def text(self):
        out = []
        for c in self.screen:
            if c == 0x0D:
                out.append("\n")
            elif c == 0x93:
                out.append("[CLR]\n")
            elif c == 0x14:
                if out:
                    out.pop()
            elif 0x20 <= c < 0x80:
                out.append(chr(c))
            else:
                out.append("{%02X}" % c)
        return "".join(out)


def run_scenario(sc, prg, verbose=False, limit=80 * CPS):
    rng = random.Random(1234)
    host = "192.168.0.64:3000"
    a = Machine("A", prg, [(0, ord("C"))] + [(300_000, ord(ch)) for ch in host] + [(300_000, 0x0D)], sc, rng)
    b = Machine("B", prg, [(0, ord("A"))], sc, rng)
    a.modem.peer, b.modem.peer = b.modem, a.modem
    while not (a.done and b.done):
        m = a if (not a.done and (b.done or a.now() <= b.now())) else b
        m.run(200)
        if m.now() > limit:
            break
    ta, tb = a.text(), b.text()
    pass_a, pass_b = "OVERALL: PASS" in ta, "OVERALL: PASS" in tb
    fail_a, fail_b = "OVERALL: FAIL" in ta, "OVERALL: FAIL" in tb
    finished = a.done and b.done
    if sc.expect_pass:
        ok = finished and pass_a and pass_b
    else:
        ok = finished and fail_a and fail_b and not (pass_a or pass_b)
    print("=== scenario %-10s expect=%s  A:%s B:%s  cycles A=%d B=%d  overruns A=%d B=%d  -> %s"
          % (sc.name, "PASS" if sc.expect_pass else "FAIL",
             "PASS" if pass_a else ("FAIL" if fail_a else "none"),
             "PASS" if pass_b else ("FAIL" if fail_b else "none"),
             a.now(), b.now(), a.overruns, b.overruns,
             "OK" if ok else "UNEXPECTED"))
    if verbose or not ok:
        print("--- A screen ---\n" + ta)
        print("--- B screen ---\n" + tb)
        print("--- modem commands A:", a.modem.log, " B:", b.modem.log)
    return ok


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    ap.add_argument("--scenario", default="all", choices=["all"] + list(SCENARIOS))
    ap.add_argument("--verbose", action="store_true")
    ap.add_argument("--prg", default=PRG)
    args = ap.parse_args()
    with open(args.prg, "rb") as f:
        prg = f.read()
    names = list(SCENARIOS) if args.scenario == "all" else [args.scenario]
    results = [run_scenario(SCENARIOS[n], prg, args.verbose) for n in names]
    print("SIMULATION SUMMARY: %d/%d scenarios behaved as expected" % (sum(results), len(results)))
    sys.exit(0 if all(results) else 1)


if __name__ == "__main__":
    main()
